%% GNSS\INS����ϣ���ͬ��GNSS_SDR,���ļ�������ͨ���ǽ���ִ�У�������һ��ͨ�����н�������������һ��ͨ��
%% ��������GNSS_SPP������Ƕ���˹ߵ�ģ��
% trackResults, channel, TOW, eph, subFrameStart ��Ҫ��ǰ׼����
settings = initSettings();
[fid, ~] = fopen(settings.fileName, 'rb');

positioningTime = TOW + settings.navSolPeriod / 1000;    % �״������ʱ��

%% INS�����Ϣ��ʼ��������ǰ��װ��PSINS
glvs
psinstypedef(153);
trj = trjfile('trj_sc522.mat');
% initial settings
[nn, ts, nts] = nnts(2, trj.ts);
imuerr = imuerrset(5,1000,0.05,30);
imu = imuadderr(trj.imu, imuerr);
davp0 = avperrset([10;10;60], 0.5, [2; 2; 6]); 

ins = insinit(avpadderr(trj.avp0,davp0), ts);
% KF filter
rk = poserrset([1;1;3]);
kf = kfinit(ins, davp0, imuerr, rk);
kf.Pmin = [avperrset(0.01,1e-4,0.1); gabias(1e-3, [1,10])].^2;  kf.pconstrain=1;

%% �ߵ��������״������֮ǰ
k = 1;
k1 = 1;            
t = imu(k1, end);   % INSʱ���
while t < positioningTime - 518400     
    k1 = k+nn-1;
    wvm = imu(k:k1,1:6);  t = imu(k1,end);
    ins = insupdate(ins, wvm);
    kf.Phikk_1 = kffk(ins);
    kf = kfupdate(kf);

    k = k + nn;      % ���ڱ�ʶ�ߵ������õ��ڼ�����
end

%% ����ͨ����ʼ������Ҫ������ͳ���ٻ��ͽ��ջ���һЩ��Ϣ����������Ϊ�źųɹ����ٵ�ͨ������֡ͬ���ɹ�
activeChnList = find([trackResults.status] ~= '-');  
numActChnList = length(activeChnList);               
BitSyncTime = subFrameStart - 1;
ii = 1;
for ch = activeChnList     
    % ������Ϣ
    % 1) PRN��
    trackDeepIn(ii).PRN = trackResults(ch).PRN;    
    % 2) ����״̬
    trackDeepIn(ii).status = trackResults(ch).status;
    % 3) �״γ���֡ͷ��λ��
    trackDeepIn(ii).SamplePos = trackResults(ch).absoluteSample(BitSyncTime(ch));
    

    trackDeepIn(ii).codeFreq = trackResults(ch).codeFreq(BitSyncTime(ch));

    trackDeepIn(ii).remCodePhase = trackResults(ch).remCodePhase(BitSyncTime(ch));

    trackDeepIn(ii).carrFreq = trackResults(ch).carrFreq(BitSyncTime(ch));

    trackDeepIn(ii).remCarrPhase = trackResults(ch).remCarrPhase(BitSyncTime(ch));


    trackDeepIn(ii).codeError = trackResults(ch).dllDiscr(BitSyncTime(ch));
    trackDeepIn(ii).codeNco = trackResults(ch).dllDiscrFilt(BitSyncTime(ch));

    trackDeepIn(ii).carrError = trackResults(ch).pllDiscr(BitSyncTime(ch));
    trackDeepIn(ii).carrNco = trackResults(ch).pllDiscrFilt(BitSyncTime(ch));
    

    trackDeepIn(ii).carrFreqBasis = channel(ch).acquiredFreq;
    
    trackDeepIn(ii).numOfCoInt = 0;

    ii = ii + 1;
end


SamplePosatFirstFrame = zeros(1, numActChnList);
for ch = 1 : numActChnList
    SamplePosatFirstFrame(ch) = trackDeepIn(ch).SamplePos;
end

settings.recvTime = TOW + (settings.startOffset)/1000;  

recvTimeforFirstFrameperChannel = getTimeforFirstFrameEachChannel(settings, SamplePosatFirstFrame);
for ii = 1 : numActChnList
    trackDeepIn(ii).recvTime = recvTimeforFirstFrameperChannel(ii);  
end

%% GNSS�������״ζ�λʱ��֮ǰ
for ii = 1 : numActChnList
    trackans = trackDeepIn(ii);
    while trackans.recvTime < positioningTime    % ����ͨ���������ʱ�̵�ʱ����һ����ɻ��֣������һ����ɻ���
        trackDeepIn(ii) = trackans;
        trackans = perChannelTrackOnce(trackans, settings, fid);
    end
end

%% GNSS INS �����
roundTime = 70;    % ����ϴ���
navResults = [];
navResults.X = zeros(1, roundTime); navResults.Y = zeros(1, roundTime); navResults.Z = zeros(1, roundTime); navResults.dt = zeros(1, roundTime);
navResults.VX = zeros(1, roundTime); navResults.VY = zeros(1, roundTime); navResults.VZ = zeros(1, roundTime);

%settings.pllNoiseBandwidth = 3;
%settings.dllNoiseBandwidth = 2;   

for currMeasNr = 1 : roundTime
    currMeasNr
    settings.recvTime = positioningTime;

    %% ����Ϲ���
    % 1. GNSS�۲�ֵ����
    navSolut = postNavLoose(trackDeepIn, settings, eph, TOW);
    [phi, lambda, h] = cart2geo(navSolut.X, navSolut.Y, navSolut.Z, 5);
    posGPS = [phi * pi/180; lambda * pi/180; h];  % pos in BLH
    
    % 2. EKF 
    kf = kfupdate(kf, ins.pos-posGPS, 'M');   % ʵ�����-���۾��� ���˴�����Ū����  ins.pos - posGPS������֮������
    [kf, ins] = kffeedback(kf, ins, 1, 'avp');

    % 3. ��¼����ϵĽ�����������ת����ECEFϵ
    [posX, posY, posZ] = geo2cart(ins.avp(7,1), ins.avp(8,1), ins.avp(9,1), 5);
    Cenu2xyz = [-sin(ins.pos(2))                  cos(ins.pos(2))                  0
                -sin(ins.pos(1))*cos(ins.pos(2)) -sin(ins.pos(1))*sin(ins.pos(2))  cos(ins.pos(1))
                 cos(ins.pos(1))*cos(ins.pos(2))  cos(ins.pos(1))*sin(ins.pos(2))  sin(ins.pos(1))];
    vxyz = Cenu2xyz' * ins.vn;
    navResults.X(1, currMeasNr) = posX;
    navResults.Y(1, currMeasNr) = posY;
    navResults.Z(1, currMeasNr) = posZ;
    navResults.dt(1,currMeasNr) = navSolut.dt;
    navResults.VX(1, currMeasNr)= vxyz(1);
    navResults.VY(1, currMeasNr)= vxyz(2);
    navResults.VZ(1, currMeasNr)= vxyz(3);

    % 4. �Ӳ�����
    for ii = 1 : numActChnList
        trackDeepIn(ii).recvTime = trackDeepIn(ii).recvTime - navSolut.dt / settings.c;  
    end
    
    % 5. ��һ�������ʱ��
    positioningTime = positioningTime + settings.navSolPeriod / 1000;

    % 6. INS��������һ�����ʱ��
    while t < positioningTime - 518400     
        k1 = k+nn-1;
        wvm = imu(k:k1,1:6);  t = imu(k1,end);
        ins = insupdate(ins, wvm);
        kf.Phikk_1 = kffk(ins);
        kf = kfupdate(kf);
    
        k = k + nn;      
    end

    % 7. GNSS��������һ�����ʱ��
    for ii = 1 : numActChnList
        trackans = trackDeepIn(ii);
        while trackans.recvTime < positioningTime     
            trackDeepIn(ii) = trackans;
            trackans = perChannelTrackOnce(trackans, settings, fid);
        end
    end
    
end


