%% GNSS\INS����ϣ���ͬ��GNSS_SDR,���ļ�������ͨ���ǽ���ִ�У�������һ��ͨ�����н�������������һ��ͨ��
% trackResults, channel, TOW, eph, subFrameStart ��Ҫ��ǰ׼����
close all;

settings = initSettings();
[fid, ~] = fopen(settings.fileName, 'rb');

positioningTime = TOW + settings.navSolPeriod / 1000;     

%% INS�����Ϣ��ʼ��������ǰ��װ��PSINS
glvs
ggpsvars
psinstypedef('test_SINS_GPS_tightly_def');
trj = trjfile('trj_sc522.mat');
[nn, ts, nts] = nnts(2, diff(trj.imu(1:2,end)));   
avp0 = trj.avp0;  % ʡȥ��ʼ��׼
davp = avperrset([10;10;60], 0.5, [2; 2; 6]);     

ins = insinit(avpadderr(trj.avp0, davp), ts);

imuerr = imuerrset(5,1000,0.05,30);  
trj.imu = imuadderr(trj.imu, imuerr);

kf = kfinit(ins, davp, imuerr);


%% INS�������׸������ʱ��
k = 1;
k1 = 1;                  
t = trj.imu(k1, end);   
while t < positioningTime - 518400     
    k1 = k+nn-1;
    wvm = trj.imu(k:k1,1:6);  t = trj.imu(k1,end);
    ins = insupdate(ins, wvm);
    kf.Phikk_1 = kffk(ins);
    kf = kfupdate(kf);

    k = k + nn;      
end

%% ����ͨ����ʼ������Ҫ������ͳ���ٻ��ͽ��ջ���һЩ��Ϣ����������Ϊ�źųɹ����ٵ�ͨ������֡ͬ���ɹ�
activeChnList = find([trackResults.status] ~= '-');   
numActChnList = length(activeChnList);               
BitSyncTime = subFrameStart - 1;
ii = 1;
for ch = activeChnList   
    trackDeepIn(ii).PRN = trackResults(ch).PRN;   

    trackDeepIn(ii).status = trackResults(ch).status;

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

    % ��¼�źŸ��ٵĹ��̣����ڵ���
    trackProcess(ii).codeErrorList = [];
    trackProcess(ii).carrErrorList = [];
    trackProcess(ii).codeFreqList = [];
    trackProcess(ii).carrFreqList = []; 
    trackProcess(ii).PLI = [];           % Phase Lock Indicator �������(���)�����������
    
    
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

%% GNSS�������״����ʱ��
I_P_1_list = [];  % ��¼������Ϣ�����ڵ���
Q_P_1_list = [];

for ii = 1 : numActChnList
    trackans = trackDeepIn(ii);
    while trackans.recvTime < positioningTime     
        trackDeepIn(ii) = trackans;
        [trackans, I_P, Q_P] = perChannelTrackOnce(trackans, settings, fid);
        
        if ii == 1
            I_P_1_list = [I_P_1_list, I_P];
            Q_P_1_list = [Q_P_1_list, Q_P];
        end
        
        trackProcess(ii).codeErrorList = [trackProcess(ii).codeErrorList, trackans.codeError];
        trackProcess(ii).carrErrorList = [trackProcess(ii).carrErrorList, trackans.carrError];
        trackProcess(ii).codeFreqList = [trackProcess(ii).codeFreqList, trackans.codeFreq];
        trackProcess(ii).carrFreqList = [trackProcess(ii).carrFreqList, trackans.carrFreq];
        trackProcess(ii).PLI = [trackProcess(ii).PLI, (I_P^2-Q_P^2)/(I_P^2+Q_P^2)];
    end
end


%% �����
roundTime = 40;     
navResults = [];
navResults.X = zeros(1, roundTime); navResults.Y = zeros(1, roundTime); navResults.Z = zeros(1, roundTime); navResults.dt = zeros(1, roundTime);
navResults.VX = zeros(1, roundTime); navResults.VY = zeros(1, roundTime); navResults.VZ = zeros(1, roundTime);navResults.df = zeros(1, roundTime);

% settings.pllNoiseBandwidth = 3;

for currMeasNr = 1 : roundTime
    currMeasNr
    settings.recvTime = positioningTime;    
     
    % ��һ�ζ�λ֮ǰ���Ӳ�������������������ʹ��һ�ε��㶨λ�Բ����Ӳ�
    if currMeasNr == 1
        navSolut_1 = postNavLoose(trackDeepIn, settings, eph, TOW);
        % �Ӳ�����
        for ii = 1 : numActChnList
            trackDeepIn(ii).recvTime = trackDeepIn(ii).recvTime - navSolut_1.dt / settings.c;  
        end
    else
        
    %% ����Ͽ�ʼ
    % 1. GNSSα�࣬α����
    navSolut = postNavTight(trackDeepIn, settings, eph, TOW);
    % ����ֻ����һ�ſɼ�����
%     navSolut.rawP = navSolut.rawP(1); navSolut.satPositions = navSolut.satPositions(:,1); 
%     navSolut.satVelocity = navSolut.satVelocity(:,1);  navSolut.satClkCorr = navSolut.satClkCorr(1); 
    

    [posxyz, ~] = blh2xyz(ins.pos);     
    % rhoSatRec����������תУ�������ڽ������˵�Ǳ����?
    [rho, LOS, AzEl] = rhoSatRec(navSolut.satPositions', posxyz, navSolut.rawP');
    el = AzEl(:,2); el(el<15*pi/180) = 1*pi/180;  P = diag(sin(el.^2));
    delta_rawP = navSolut.rawP' + settings.c * navSolut.satClkCorr' - rho;   % ʵ�����-���۾��� 
    
    % 2. EKF
    kf.Hk = kfhk(ins, LOS);     % �۲����H
    kf.Rk = P^-1 * 10^2;        % �۲�����Э�������R
    kf = kfupdate(kf, delta_rawP);
    [kf, ins] = kffeedback(kf, ins, 1, 'avp');  
    
    % 3. ��������ת����ECEF����ϵ����¼
    [posX, posY, posZ] = geo2cart(ins.avp(7,1), ins.avp(8,1), ins.avp(9,1), 5);
    Cenu2xyz = [-sin(ins.pos(2))                  cos(ins.pos(2))   0
                -sin(ins.pos(1))*cos(ins.pos(2)) -sin(ins.pos(1))*sin(ins.pos(2))  cos(ins.pos(1))
                 cos(ins.pos(1))*cos(ins.pos(2))  cos(ins.pos(1))*sin(ins.pos(2))  sin(ins.pos(1))];
    vxyz = Cenu2xyz' * ins.vn;
    navResults.X(1, currMeasNr) = posX;  navResults.Y(1, currMeasNr) = posY;
    navResults.Z(1, currMeasNr) = posZ;  navResults.dt(1, currMeasNr) = kf.xk(end-1);
    navResults.VX(1, currMeasNr)= vxyz(1);
    navResults.VY(1, currMeasNr)= vxyz(2);
    navResults.VZ(1, currMeasNr)= vxyz(3); navResults.df(1, currMeasNr) = kf.xk(end);
    
    % 4. �Ӳ�����
    for ii = 1 : numActChnList
        trackDeepIn(ii).recvTime = trackDeepIn(ii).recvTime - kf.xk(end-1) / settings.c;  
    end
    
    end
    
    % 5. ��һ�ν����ʱ��
    positioningTime = positioningTime + settings.navSolPeriod / 1000;

    % 6. INS��������һ�ν����ʱ��
    while t < positioningTime - 518400     
        k1 = k+nn-1;
        wvm = trj.imu(k:k1,1:6);  t = trj.imu(k1,end);
        ins = insupdate(ins, wvm);
        kf.Phikk_1 = kffk(ins);
        kf = kfupdate(kf);
     
        k = k + nn;       
        
    end

    % 7. GNSS��������һ�ν����ʱ��
    for ii = 1 : numActChnList
        trackans = trackDeepIn(ii);
        while trackans.recvTime < positioningTime     
            trackDeepIn(ii) = trackans;
            [trackans, I_P, Q_P] = perChannelTrackOnce(trackans, settings, fid);

            if trackans.recvTime < positioningTime
                trackProcess(ii).codeErrorList = [trackProcess(ii).codeErrorList, trackans.codeError];
                trackProcess(ii).carrErrorList = [trackProcess(ii).carrErrorList, trackans.carrError];
                trackProcess(ii).codeFreqList = [trackProcess(ii).codeFreqList, trackans.codeFreq];
                trackProcess(ii).carrFreqList = [trackProcess(ii).carrFreqList, trackans.carrFreq];
                trackProcess(ii).PLI = [trackProcess(ii).PLI, (I_P^2-Q_P^2)/(I_P^2+Q_P^2)];
                
                if ii == 1
                    I_P_1_list = [I_P_1_list, I_P];
                    Q_P_1_list = [Q_P_1_list, Q_P];
                end
            end
        end
    end
    
    
end










