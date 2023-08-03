function [navSolut, satPositions, satVelocity, satClkCorr, rawP, rawP_dot] = postNavLoose(trackDeepIn, settings, eph, TOW)
%% ��С���˶�λ���㣬Ϊ�����������׼�����������ǽ������ƣ�?
%
% �������:
%        - trackDeepIn: ���ٽṹ�壬ͨ��֮�������׼ͬ�������������ʱ�̲���һ����ɻ�������?
%        - settings: ���ջ���ز���?
%        - eph: ����
%        - TOW: �׸���֡֡ͷ�ķ���ʱ��?
%
% 输出参数:
%        - navSolut: GNSS�۲�ֵ�ṹ��
%
%--------------------------------------------------------------------------
%% �ɹ����ٵ�ͨ��������4������ʧ��?
numActChnList = length(trackDeepIn);

if (isempty(trackDeepIn) || (size(trackDeepIn, 2) < 4))
    % Show error message and exit
    disp('Too few satellites with ephemeris data for postion calculations. Exiting!');
    navSolut = [];
    return
end

%% �������ʱ��α��Ͷ�����
launchTime = zeros(1, numActChnList);
rawP = zeros(1, numActChnList);
doppler = zeros(1, numActChnList);
remSampleNum = zeros(1, numActChnList);
totalSampleNum = zeros(1, numActChnList);

for ii = 1 : numActChnList
    % ��ͨ���������ʱ�̻�����ٸ�������
    remSampleNum(ii) = fix((settings.recvTime - trackDeepIn(ii).recvTime) * settings.samplingFreq);
    totalSampleNum(ii) = trackDeepIn(ii).SamplePos + remSampleNum(ii);  
end
% ���ò��������ʱ�䣬�˴����ܴ������������һ���㽫���3e8/15e6=20m�ľ޴����
maxTotal = max(totalSampleNum);  % �����ĵ�������
for ii = 1 : numActChnList
    remSampleNum(ii) = remSampleNum(ii) + (maxTotal - totalSampleNum(ii));
end

for ii = 1 : numActChnList   
    % ��ͨ����Ӧ������λ����
    codePhaseStep = trackDeepIn(ii).codeFreq / settings.samplingFreq;
    
    % ��λ�þ����״γ���֡ͷ����ɻ��ִ���
    num_Cyclic = trackDeepIn(ii).numOfCoInt;
        
    % ����һ���ܵ�α������λ
    codePhaseTao = trackDeepIn(ii).remCodePhase + codePhaseStep * ( remSampleNum(ii) - 1 );  % -1?
    
    % �������ʱ�̵������źŷ���ʱ��
    launchTime(ii) = TOW + num_Cyclic * 1e-3 + codePhaseTao / 1023 * 1e-3;   % [s]

    % ����α��
    rawP(ii) = (settings.recvTime - launchTime(ii)) * settings.c; 

    % ��������� [Hz]
    doppler(ii) = trackDeepIn(ii).carrFreq - settings.IF;
end
rawP_dot = -doppler .* settings.c / 1575.42e6;

%% ��������λ�õ���Ϣ
[satPositions, satVelocity, satClkCorr, satClkDrift] = satpos_zcj(launchTime, ...
                                [trackDeepIn.PRN], eph);

%% ��С���˶�λ?
[xyzdt, vxyzdf, el, az, DOP] = ...
            leastSquarePos_zcj(satPositions, satVelocity, ...                         % ����λ�ú��ٶ�
            rawP + satClkCorr * settings.c, rawP_dot + satClkDrift * settings.c, ...  % ��������������������α���α����
            settings);

% ��¼���
navSolut.X = xyzdt(1,1);    navSolut.Y = xyzdt(1,2);    navSolut.Z = xyzdt(1,3);    navSolut.dt = xyzdt(1,4);
navSolut.VX = vxyzdf(1,1);  navSolut.VY = vxyzdf(1,2);  navSolut.VZ = vxyzdf(1,3);  navSolut.df = vxyzdf(1,4);
navSolut.DOP = DOP;    navSolut.el = el;    navSolut.az = az;
navSolut.recvTime = settings.recvTime - navSolut.dt / settings.c;

end
