%% GNSS���㶨λ����ͬ��GNSS_SDR,���ļ�������ͨ���ǽ���ִ�У�������һ��ͨ�����н�������������һ��ͨ��
settings = initSettings();
[fid, message] = fopen(settings.fileName, 'rb');

%% ����ͨ����ʼ������Ҫ������ͳ���ٻ��ͽ��ջ���һЩ��Ϣ����������Ϊ�źųɹ����ٵ�ͨ������֡ͬ���ɹ�
% ��¼�״γ���֡ͷ��ʱ�򣬸�ͨ���ĸ������
activeChnList = find([trackResults.status] ~= '-');   % �ɹ������źŵ�ͨ��
numActChnList = length(activeChnList);                % �ɹ������źŵ�ͨ������
BitSyncTime = subFrameStart - 1;
ii = 1;
for ch = activeChnList      % ȥ������ʧ�ܵ�ͨ����trackDeepIn��С���ڳɹ����ٵ�ͨ����[][][][][][][][][]
    % ������Ϣ
    % 1) PRN��
    trackDeepIn(ii).PRN = trackResults(ch).PRN;     
    % 2) ����״̬
    trackDeepIn(ii).status = trackResults(ch).status;
    % 3) �״γ���֡ͷ��λ��
    trackDeepIn(ii).SamplePos = trackResults(ch).absoluteSample(BitSyncTime(ch));
    
    % ������Ϣ
    % 1. ��Ƶ��
    trackDeepIn(ii).codeFreq = trackResults(ch).codeFreq(BitSyncTime(ch));
    % 2. ����λ�в�
    trackDeepIn(ii).remCodePhase = trackResults(ch).remCodePhase(BitSyncTime(ch));
    % 3. �ز�Ƶ��
    trackDeepIn(ii).carrFreq = trackResults(ch).carrFreq(BitSyncTime(ch));
    % 4. �ز���λ��
    trackDeepIn(ii).remCarrPhase = trackResults(ch).remCarrPhase(BitSyncTime(ch));

    % 5. ��NCO
    trackDeepIn(ii).codeError = trackResults(ch).dllDiscr(BitSyncTime(ch));
    trackDeepIn(ii).codeNco = trackResults(ch).dllDiscrFilt(BitSyncTime(ch));
    % 6. �ز�NCO
    trackDeepIn(ii).carrError = trackResults(ch).pllDiscr(BitSyncTime(ch));
    trackDeepIn(ii).carrNco = trackResults(ch).pllDiscrFilt(BitSyncTime(ch));
    
    % 7. �ز���׼Ƶ�ʣ�����ֵ���Բ���
    trackDeepIn(ii).carrFreqBasis = channel(ch).acquiredFreq;
    
    % 8. ����֡ͷ��ʼ�����ֽ����˼�����ɻ��֣����ڼ��㷢��ʱ�䣩
    trackDeepIn(ii).numOfCoInt = 0;
    
    % 9. ����һЩ�м��������ڲ鿴���ٻ����
    trackProcess(ii).codeErrorList = [];
    trackProcess(ii).carrErrorList = [];
    trackProcess(ii).codeFreqList = [];
    trackProcess(ii).carrFreqList = []; 

    ii = ii + 1;
end

% ������¼���״γ���֡ͷʱ�ĸ�����������ڵ���
SamplePosatFirstFrame = zeros(1, numActChnList);
for ch = 1 : numActChnList
    SamplePosatFirstFrame(ch) = trackDeepIn(ch).SamplePos;
end

%% ��ʼ���㶨λ
roundTime = 10;    % ��λ��������Ҫ����GNSS Obs�ĸ���
navResults = [];
navResults.X = zeros(1, roundTime); navResults.Y = zeros(1, roundTime); navResults.Z = zeros(1, roundTime); navResults.dt = zeros(1, roundTime);
navResults.VX = zeros(1, roundTime); navResults.VY = zeros(1, roundTime); navResults.VZ = zeros(1, roundTime); navResults.df = zeros(1, roundTime);


for currMeasNr = 1 : roundTime
    currMeasNr  
    
%     if currMeasNr > 16                     % �����й������޸Ĵ���
%     settings.pllNoiseBandwidth = 5;
%     settings.dllNoiseBandwidth = 0.5;
%     end
    
    if currMeasNr == 1
        positioningTime = TOW + settings.navSolPeriod / 1000;   % �涨һ���״�ʵ�ֶ�λ��ʱ��
        
        % �����һ��ͨ���״γ�����֡֡ͷʱ�Ľ��ջ�����ʱ�����ֵ(��ʵ���״ζ�λ֮ǰ�޷��õ�׼ȷ�Ľ��ջ�����ʱ��)
        settings.recvTime = TOW + (settings.startOffset)/1000;  

        % ÿ��ͨ���״γ�����֡֡ͷʱ���ջ�����ʱ�����ֵ?
        recvTimeforFirstFrameperChannel = getTimeforFirstFrameEachChannel(settings, SamplePosatFirstFrame);
        for ii = 1 : numActChnList
            trackDeepIn(ii).recvTime = recvTimeforFirstFrameperChannel(ii);  % ������Ϣ�ϲ���trackDeepIn�ṹ��
        end
    end
    
    settings.recvTime = positioningTime; % ���ý��ջ�����ʱ��Ϊ��λʱ�̣����ٻ�����������ʱ��
    
    % ÿ��ͨ�����и���ֱ�����ﶨλʱ��֮ǰ����νͨ�����׼ͬ����
    for ii = 1 : numActChnList
        trackans = trackDeepIn(ii);
        while trackans.recvTime < positioningTime    % ����ͨ���������ʱ�̵�ʱ����һ����ɻ��֣������һ����ɻ���
            trackDeepIn(ii) = trackans;
            trackans = perChannelTrackOnce(trackans, settings, fid);
            
            if trackans.recvTime < positioningTime
                trackProcess(ii).codeErrorList = [trackProcess(ii).codeErrorList, trackans.codeError];
                trackProcess(ii).carrErrorList = [trackProcess(ii).carrErrorList, trackans.carrError];
                trackProcess(ii).codeFreqList = [trackProcess(ii).codeFreqList, trackans.codeFreq];
                trackProcess(ii).carrFreqList = [trackProcess(ii).carrFreqList, trackans.carrFreq];
        
            end
        end
    end
    
    navSolut = postNavLoose(trackDeepIn, settings, eph, TOW);
    navResults.X(1,currMeasNr) = navSolut.X; navResults.Y(1,currMeasNr) = navSolut.Y; navResults.Z(1,currMeasNr) = navSolut.Z;
    navResults.VX(1,currMeasNr) = navSolut.VX; navResults.VY(1,currMeasNr) = navSolut.VY; navResults.VZ(1,currMeasNr) = navSolut.VZ;
    navResults.dt(1,currMeasNr) = navSolut.dt;  navResults.df(1,currMeasNr) = navSolut.df;
    
    % �Ӳ�����
    for ii = 1 : numActChnList
        trackDeepIn(ii).recvTime = trackDeepIn(ii).recvTime - navSolut.dt / settings.c;   
    end
    
    % ������һ�ζ�λʱ��
    positioningTime = positioningTime + settings.navSolPeriod / 1000;
end


