function navSolut = postNavTight(trackDeepIn, settings, eph, TOW)
%% GNSS���������׼�����������ǽ������ƣ�
%
% �������:
%        - trackDeepIn: ���ٽṹ�壬ͨ��֮�������׼ͬ�������������ʱ�̲���һ����ɻ�������
%        - settings: ���ջ���ز���
%        - eph: ����
%        - TOW: �׸���֡֡ͷ�ķ���ʱ��
%
% �������:
%        - navSolut: GNSS�۲�ֵ�ṹ�壬α���α���ʡ�����λ
%
%--------------------------------------------------------------------------
%% 
numActChnList = length(trackDeepIn);

if (isempty(trackDeepIn) || (size(trackDeepIn, 2) < 1))
    disp('Too few satellites with ephemeris data for postion calculations. Exiting!');
    navSolut = [];
    return
end

%% �����źŷ���ʱ��
launchTime = zeros(1, numActChnList);
rawP = zeros(1, numActChnList);
doppler = zeros(1, numActChnList);
remSampleNum = zeros(1, numActChnList);
totalSampleNum = zeros(1, numActChnList);

for ii = 1 : numActChnList
    remSampleNum(ii) = fix((settings.recvTime - trackDeepIn(ii).recvTime) * settings.samplingFreq);
    totalSampleNum(ii) = trackDeepIn(ii).SamplePos + remSampleNum(ii);  
end

maxTotal = max(totalSampleNum);
for ii = 1 : numActChnList
    remSampleNum(ii) = remSampleNum(ii) + (maxTotal - totalSampleNum(ii));
end

for ii = 1 : numActChnList   
    codePhaseStep = trackDeepIn(ii).codeFreq / settings.samplingFreq;
    num_Cyclic = trackDeepIn(ii).numOfCoInt;

    codePhaseTao = trackDeepIn(ii).remCodePhase + codePhaseStep * ( remSampleNum(ii) - 1 );  % -1?

    launchTime(ii) = TOW + num_Cyclic * 1e-3 + codePhaseTao / 1023 * 1e-3;   % [s]

    rawP(ii) = (settings.recvTime - launchTime(ii)) * settings.c; 

    doppler(ii) = trackDeepIn(ii).carrFreq - settings.IF;
end
rawP_dot = -doppler .* settings.c / 1575.42e6;

%% 
[satPositions, satVelocity, satClkCorr, satClkDrift] = satpos_zcj(launchTime, ...
                                [trackDeepIn.PRN], eph);

%% 
navSolut.rawP = rawP;  navSolut.rawP_dot = rawP_dot;  
navSolut.satClkCorr = satClkCorr;  navSolut.satClkDrift = satClkDrift;  navSolut.satPositions = satPositions;
navSolut.satVelocity = satVelocity;

end
