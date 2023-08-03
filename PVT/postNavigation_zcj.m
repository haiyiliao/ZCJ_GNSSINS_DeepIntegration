function [navSolutions, eph, subFrameStart, TOW] = postNavigation_zcj(trackResults, settings)

if (settings.msToProcess < 36000) || (sum([trackResults.status] ~= '-') < 4)
    disp('Record is to short or too few satellites tracked. Exiting!');
    navSolutions = [];
    eph          = [];
    return
end

%% ֡ͬ�� ==========================================
% firstSubFrameSampleNum with size 1,settings.numberOfChannels, if cannot
% find the first Sub Frame because of tracking failure or Frame alignment
% failure, firstSubFrameSampleNum = 0, else firstSubFrameSampleNum = the
% number of samples corresponding to the first SubFrame appeared
[subFrameStart, activeChnList, ~] = findPreambles(trackResults, settings);

%% ���
for channelNr = activeChnList

    %=== ���źŸ��ٵõ���I_Pת��Ϊ���ı��� =======================

    %--- Copy 5 sub-frames long record from tracking output ---------------
    % 1500 = 5 * 10 * 30
    % subFrameStart(channelNr) - 20 ��ʾ�ƶ�����bit֮ǰ
    navBitsSamples = trackResults(channelNr).I_P(subFrameStart(channelNr) - 20 : ...
                               subFrameStart(channelNr) + (1500 * 20) -1)';

    %--- Group every 20 vales of bits into columns ------------------------
    navBitsSamples = reshape(navBitsSamples, ...
                             20, (size(navBitsSamples, 1) / 20));

    %--- Sum all samples in the bits to get the best estimate -------------
    navBits = sum(navBitsSamples);

    %--- Now threshold and make 1 and 0 -----------------------------------
    % The expression (navBits > 0) returns an array with elements set to 1
    % if the condition is met and set to 0 if it is not met.
    navBits = (navBits > 0);

    %--- Convert from decimal to binary -----------------------------------
    % The function ephemeris expects input in binary form. In Matlab it is
    % a string array containing only "0" and "1" characters.
    navBitsBin = dec2bin(navBits);
    
    %=== Decode ephemerides and TOW of the first sub-frame ================
    [eph(trackResults(channelNr).PRN), TOW] = ...
                            ephemeris(navBitsBin(2:1501)', navBitsBin(1));  
    % �˴�������Ϊÿ��ͨ����֡ͬ���õ����׸�TOW������ͬ�ģ���ʵ�������һ�����п���
    % ĳͨ���Ѿ�֡ͬ����ɣ�����һͨ������֡ͬ�������С������в�ͬ��TOW��

    % ȥ���Ҳ���������ͨ��
    if (isempty(eph(trackResults(channelNr).PRN).IODC) || ...
        isempty(eph(trackResults(channelNr).PRN).IODE_sf2) || ...
        isempty(eph(trackResults(channelNr).PRN).IODE_sf3))

        %--- Exclude channel from the list (from further processing) ------
        activeChnList = setdiff(activeChnList, channelNr);
    end    
end

%% �Ƿ����3�����Ͽ��õ����� =====================
if (isempty(activeChnList) || (size(activeChnList, 2) < 4))
    disp('Too few satellites with ephemeris data for postion calculations. Exiting!');
    navSolutions = [];
    eph          = [];
    return
end

%% ��ʼ����λ��Ϣ ===================================================
satElev  = inf(1, settings.numberOfChannels);
readyChnList = activeChnList;
transmitTimefortheFirstFrameRecvd = TOW;     % the first Frame transmit Time in GPST [s]

positioningTimes = fix((settings.msToProcess - max(subFrameStart)) / settings.navSolPeriod);  % Times of positioning

navSolutions = [];
navSolutions.channel.PRN         = zeros(settings.numberOfChannels, positioningTimes);
navSolutions.channel.el          = zeros(settings.numberOfChannels, positioningTimes);
navSolutions.channel.az          = zeros(settings.numberOfChannels, positioningTimes);
navSolutions.channel.rawP        = zeros(settings.numberOfChannels, positioningTimes);
navSolutions.channel.correctedP  = zeros(settings.numberOfChannels, positioningTimes);
navSolutions.channel.doppler     = zeros(settings.numberOfChannels, positioningTimes);

navSolutions.DOP                 = zeros(5, positioningTimes);
navSolutions.X                   = zeros(1, positioningTimes);
navSolutions.Y                   = zeros(1, positioningTimes);
navSolutions.Z                   = zeros(1, positioningTimes);
navSolutions.dt                  = zeros(1, positioningTimes);

navSolutions.VX                  = zeros(1, positioningTimes);
navSolutions.VY                  = zeros(1, positioningTimes);
navSolutions.VZ                  = zeros(1, positioningTimes);
navSolutions.df                  = zeros(1, positioningTimes);

navSolutions.receiverTime        = zeros(1, positioningTimes);

%% ��ʼ��λ
for currMeasNr = 1:fix((settings.msToProcess - max(subFrameStart)) / ...
                                                     settings.navSolPeriod)
    
    % ȥ������������ 
    activeChnList = intersect(find(satElev >= settings.elevationMask), ...
                              readyChnList);
                                                 
    % Save list of satellites used for position calculation; if satElev <
    % Mask, then PRN will be set to 0
    for ii = 1 : length(activeChnList)
        navSolutions.channel.PRN(activeChnList(ii), currMeasNr) = ...
                                            [trackResults(activeChnList(ii)).PRN]; 
    end
                                     
    %% From now on, I have done some changes
    if currMeasNr == 1    % �״ζ�λ
        settings.startOffset = 80.000;
        settings.recvTime    = settings.startOffset / 1000 + TOW;   % ���ջ���ʵ���״ζ�λʱ�ı���ʱ����δ֪�ģ����Ǽٶ�һ��ʱ�䣬��TOW+80ms 
    end
    
    % ����α�� ======================================================
    % transmitTimeatSat: ���Ƿ����źŵ���ʵʱ��  
    % doppler: ��Ծͨ��Dopplerֵ [Hz]
    [rawP, transmitTimeatSat, doppler] = calculatePseudoranges_zcj(...
        trackResults, subFrameStart + settings.navSolPeriod * (currMeasNr-1), ...
        activeChnList, settings, TOW + settings.navSolPeriod * (currMeasNr-1) * 1e-3); 
    rawP_dot = -(doppler) * settings.c / 1575.42e6;   % XieGang 5.74 α��仯��
    for ii =  1 : length(activeChnList)
        navSolutions.channel.rawP(activeChnList(ii), currMeasNr) = rawP(ii);
        navSolutions.channel.doppler(activeChnList(ii), currMeasNr) = doppler(ii);
    end
    
    
    % �����źŷ���ʱ�����ǵ�λ�� =======================
    [satPositions, satVelocity, satClkCorr, satClkDrift] = satpos_zcj(transmitTimeatSat, ...
                                    [trackResults(activeChnList).PRN], eph);

    if length(activeChnList) > 3
        % === ��С���˶�λ ==================================
        [xyzdt, vxyzdf, el, az, navSolutions.DOP(:, currMeasNr)] = ...
            leastSquarePos_zcj(satPositions, satVelocity, ...                         % ����λ�ú��ٶ�
            rawP + satClkCorr * settings.c, rawP_dot + satClkDrift * settings.c, ...  % α�ಹ�������Ӳλ���ʲ���������Ư
            settings);
        for ii = 1 : length(activeChnList) 
            navSolutions.channel.el(activeChnList(ii), currMeasNr) = el(ii);
            navSolutions.channel.az(activeChnList(ii), currMeasNr) = az(ii);
        end

        %--- ������ -------------------------------------------------
        navSolutions.X(currMeasNr)  = xyzdt(1);
        navSolutions.Y(currMeasNr)  = xyzdt(2);
        navSolutions.Z(currMeasNr)  = xyzdt(3);
        navSolutions.dt(currMeasNr) = xyzdt(4);
        
        navSolutions.VX(currMeasNr) = vxyzdf(1);
        navSolutions.VY(currMeasNr) = vxyzdf(2);
        navSolutions.VZ(currMeasNr) = vxyzdf(3);
        navSolutions.df(currMeasNr) = vxyzdf(4);

        % === Correct pseudorange measurements for clocks errors ===========
        % according to XieGang P70 4.7 formula, the symbol before dt should be 'minus' instead of plus
        navSolutions.channel.correctedP(activeChnList, currMeasNr) = ...
            navSolutions.channel.rawP(activeChnList, currMeasNr) + ...
            satClkCorr' * settings.c - navSolutions.dt(currMeasNr);   

        % align receiver local time to receiver GPS Time �Ӳ��
        settings.recvTime = settings.recvTime - navSolutions.dt(currMeasNr) / settings.c; 
        navSolutions.receiverTime(currMeasNr) = settings.recvTime;
        
       %% Coordinate conversion ==================================================

        %=== Convert to geodetic coordinates ==============================
        [navSolutions.latitude(currMeasNr), ...
         navSolutions.longitude(currMeasNr), ...
         navSolutions.height(currMeasNr)] = cart2geo(...
                                            navSolutions.X(currMeasNr), ...
                                            navSolutions.Y(currMeasNr), ...
                                            navSolutions.Z(currMeasNr), ...
                                            5);

        %=== Convert to UTM coordinate system =============================
        navSolutions.utmZone = findUtmZone(navSolutions.latitude(currMeasNr), ...
                                           navSolutions.longitude(currMeasNr));
        
        [navSolutions.E(currMeasNr), ...
         navSolutions.N(currMeasNr), ...
         navSolutions.U(currMeasNr)] = cart2utm(xyzdt(1), xyzdt(2), ...
                                                xyzdt(3), ...
                                                navSolutions.utmZone);
    else
        %--- There are not enough satellites to find 3D position ----------
        disp(['   Measurement No. ', num2str(currMeasNr), ...
                   ': Not enough information for position solution.']);
    end
    
    %%   
    % receiver local time at next epoch 
    settings.recvTime = settings.recvTime + settings.navSolPeriod / 1000;
        
    % Update the satellites elevations vector
    satElev = navSolutions.channel.el(:, currMeasNr)';
    
end

end