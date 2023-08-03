function [trackResults, channel]= trackpll2nd(fid, channel, settings)
% Performs code and carrier tracking for all channels.
%
%[trackResults, channel] = tracking(fid, channel, settings)
%
%   Inputs:
%       fid             - file identifier of the signal record.
%       channel         - PRN, carrier frequencies and code phases of all
%                       satellites to be tracked (prepared by preRum.m from
%                       acquisition results).
%       settings        - receiver settings.
%   Outputs:
%       trackResults    - tracking results (structure array). Contains
%                       in-phase prompt outputs and absolute starting 
%                       positions of spreading codes, together with other
%                       observation data from the tracking loops. All are
%                       saved every millisecond.

%--------------------------------------------------------------------------


%% ��ʼ���źŸ��ٽṹ�� ============================================

% �źŸ���״̬
trackResults.status         = '-';      % '-'��ʾ��ͨ�����ź�

% ÿһ����ɻ��ֽ����������ļ�ָ���λ��
trackResults.absoluteSample = zeros(1, settings.msToProcess);

% CA��Ƶ��
trackResults.codeFreq       = inf(1, settings.msToProcess);

% �ز�Ƶ��
trackResults.carrFreq       = inf(1, settings.msToProcess);

% E,L,P֧·I·
trackResults.I_P            = zeros(1, settings.msToProcess);
trackResults.I_E            = zeros(1, settings.msToProcess);
trackResults.I_L            = zeros(1, settings.msToProcess);

% E,L,P֧·Q·
trackResults.Q_E            = zeros(1, settings.msToProcess);
trackResults.Q_P            = zeros(1, settings.msToProcess);
trackResults.Q_L            = zeros(1, settings.msToProcess);

% ���������
trackResults.dllDiscr       = inf(1, settings.msToProcess);
trackResults.pllDiscr       = inf(1, settings.msToProcess);

% NCO���
trackResults.dllDiscrFilt   = inf(1, settings.msToProcess);
trackResults.pllDiscrFilt   = inf(1, settings.msToProcess);

%------------------------ Ϊÿһ��ͨ����ʼ�� -------------------------------
trackResults = repmat(trackResults, 1, settings.numberOfChannels);

%% ��ʼ���źŸ��ٵ���ز��� ==========================================

codePeriods = settings.msToProcess;     % For GPS one C/A code is one ms

%--- DLL ���� --------------------------------------------------------
% �������� (in chips)
earlyLateSpc = settings.dllCorrelatorSpacing;

% �뻷�������ڣ��ڸú����е�����ɻ���ʱ��
PDIcode = 0.001;

% 2��DLL��·�˲���ϵ������
[tau1code, tau2code] = calcLoopCoef(settings.dllNoiseBandwidth, ...
                                    settings.dllDampingRatio, ...
                                    1.0);

%--- PLL ���� --------------------------------------------------------
% �ز����������ڣ��ڸú����е�����ɻ���ʱ��
PDIcarr = 0.001;

% 2��PLL��·�˲���ϵ������
a2 = 1.414;
wn = settings.pllNoiseBandwidth / 0.53;
kca1 = wn ^ 2 * PDIcarr / settings.pllLoopGain;
kca2 = a2 * wn / settings.pllLoopGain;

hwb = waitbar(0,'Tracking...');

%% ��ʼ�źŸ��� ==============================================
for channelNr = 1:settings.numberOfChannels
    
    % ����ɹ��������ͨ��PRN�Ų�Ϊ0
    if (channel(channelNr).PRN ~= 0)

        trackResults(channelNr).PRN     = channel(channelNr).PRN;
        
        % �ƶ������񵽵�����λ�����������λ����׼ȷ���ƶ�������λӦ��Ϊ0
        fseek(fid, ...
              settings.fileType * settings.dataFormat * (settings.skipNumberOfSamples + channel(channelNr).codePhase-1), ...
              'bof');

        % ����CA��
        caCode = generateCAcode(channel(channelNr).PRN);
        % ǰ������һ����Ƭ
        caCode = [caCode(1023) caCode caCode(1)];

        %--- ��ʼ��һЩ�������ڲ��� ------------------------------
      
        codeFreq      = settings.codeFreqBasis;     % ��Ƶ�ʳ�ʼ��Ϊ1.023e6����  
        remCodePhase  = 0.0;                        % ��һ�ֵ�����ʼ��λ
    
        carrFreq      = channel(channelNr).acquiredFreq;  % �ز�Ƶ�ʳ�ʼ��Ϊ���񵽵�Ƶ��
        carrFreqBasis = channel(channelNr).acquiredFreq;  % �ز����Ļ�׼Ƶ�ʳ�ʼ��Ϊ���񵽵�Ƶ��
        remCarrPhase  = 0.0;                              % ��һ�ֵ��ز���ʼ��λ

        % �뻷��·�˲������м�����ʼ��
        oldCodeNco   = 0.0;
        oldCodeError = 0.0;

        % �ز�����·�˲������м�����ʼ��
        zkminus1     = 0.0;             % ��Ӧ��PLL�ź���ͼ��һ����ʱ��֮���λ��
        oldCarrError = 0.0;
        
        % ͨ��֮�䴮�и��٣���һ��ͨ��ȫ�����ٽ���֮���ٸ�����һͨ��
        for loopCnt =  1:codePeriods
            
%% ���ٽ����� -------------------------------------------------------------
            % ������ÿ50����ɻ��ָ���һ��
            if (rem(loopCnt, 50) == 0)
                try
                    waitbar(loopCnt/codePeriods, ...
                            hwb, ...
                            ['Tracking: Ch ', int2str(channelNr), ...
                            ' of ', int2str(settings.numberOfChannels), ...
                            '; PRN#', int2str(channel(channelNr).PRN), ...
                            '; Completed ',int2str(loopCnt), ...
                            ' of ', int2str(codePeriods), ' msec']);                       
                catch
                    % ������������ر����Զ��˳�����
                    disp('Progress bar closed, exiting...');
                    return
                end
            end

%% ����һ����ɻ������ݿ� ------------------------------------------------                        
            
            % ���ڵ�ǰ�뻷����õ�����Ƶ����˵��һ���������Ӧ������λ�������Ƕ��� 
            codePhaseStep = codeFreq / settings.samplingFreq;   
            
            % ���ڵ�ǰ�뻷����õ�����Ƶ�ʡ���ǰ���ڵ���ʼ����λ��ÿ���������Ӧ����λ��������˵��
            % ����һ�����ڵ����Ӧ���ٲ����㣨����ֵ�Ĵ�С�ڸú�����Լ����1ms��Ӧ�Ĳ����������
            blksize = ceil((settings.codeLength - remCodePhase) / codePhaseStep);  
            
            % ��ȡ��Ӧ�����Ĳ�����
            [rawSignal, samplesRead] = fread(fid, ...
                                             settings.fileType * blksize, settings.dataType);
            rawSignal = transpose(rawSignal);  % ת�ã�ע�����ﲻҪ��'��'�ű�ʾ����ת��
            if settings.fileType == 2
                rawSignalI = rawSignal(1:2:end);
                rawSignalQ = rawSignal(2:2:end);
                rawSignal  = rawSignalI + 1j * rawSignalQ; Flag = 0; 
                % rawSignal  = rawSignalI + 0 * rawSignalQ;  Flag = 1;  % I,Q not combined               
            end
                                                               
            % ������ݲ����ˣ�ֱ���˳�
            if (samplesRead ~= settings.fileType * blksize)
                disp('Not able to read the specified number of samples  for tracking, exiting!')
 %               fclose(fid);
                return
            end

%% ����E��L��P֧·��Ӧ���� ------------------------------------------
            % E֧·
            tcode       = (remCodePhase-earlyLateSpc) : ...
                          codePhaseStep : ...
                          ((blksize-1)*codePhaseStep+remCodePhase-earlyLateSpc);
            tcode2      = ceil(tcode) + 1;
            earlyCode   = caCode(tcode2);
            
            % L֧·
            tcode       = (remCodePhase+earlyLateSpc) : ...
                          codePhaseStep : ...
                          ((blksize-1)*codePhaseStep+remCodePhase+earlyLateSpc);
            tcode2      = ceil(tcode) + 1;
            lateCode    = caCode(tcode2);
            
            % P֧·
            tcode       = remCodePhase : ...
                          codePhaseStep : ...
                          ((blksize-1)*codePhaseStep+remCodePhase);
            tcode2      = ceil(tcode) + 1;
            promptCode  = caCode(tcode2);
            
            remCodePhase = (tcode(blksize) + codePhaseStep) - 1023.0;  % ������һ��CA�����ʼ��λ����֤����λ����

%% �����ز� -------------------------------------------------------
            time    = (0:blksize) ./ settings.samplingFreq;
            
            % �����ز���λ
            trigarg = ((carrFreq * 2.0 * pi) .* time) + remCarrPhase;  % remCarrPhase��Ϊ���ֵ���ʼ��λ�������ܱ���ÿһ�ֵ���λ����        
            remCarrPhase = rem(trigarg(blksize+1), (2 * pi));          % ������һ���ز�����ʼ��λ
    
            % ʵ���ݺ͸����ݷֿ������Ƿ��б�Ҫ���Ժ���˵
            if settings.fileType == 1 || Flag == 1
                carrCos = cos(trigarg(1:blksize));
                carrSin = sin(trigarg(1:blksize));
                qBasebandSignal = carrCos .* rawSignal;
                iBasebandSignal = carrSin .* rawSignal;
                             
            else
                carr = exp(-1j* trigarg(1:blksize));
                qBasebandSignal = imag(carr .* rawSignal);
                iBasebandSignal = real(carr .* rawSignal);
            end
                        
            % ��ɻ���
            I_E = sum(earlyCode  .* iBasebandSignal);
            Q_E = sum(earlyCode  .* qBasebandSignal);
            I_P = sum(promptCode .* iBasebandSignal);
            Q_P = sum(promptCode .* qBasebandSignal);
            I_L = sum(lateCode   .* iBasebandSignal);
            Q_L = sum(lateCode   .* qBasebandSignal);            
            
%% PLL��·���� -----------------------------------------------------
            % ��������atan(Q_P / I_P)�ĵ�λΪ���ȣ�����2pi��λ��� '��'��Ҳ�ȼ���Hz
            carrError = atan(Q_P / I_P) / (2.0 * pi);
            
            % ��·�˲�����ʱ��ʽ���Ǵ�Z��ת���õ�
            zk = zkminus1 + (carrError + oldCarrError) * kca1;  
            carrNco = zk / 2 + carrError * kca2;
            zkminus1 = zk;
            oldCarrError = carrError;
           
            % �����ز�Ƶ��
            carrFreq = carrFreqBasis + carrNco;
            trackResults(channelNr).carrFreq(loopCnt) = carrFreq; % ��¼�ز�Ƶ��

%% DLL��·���� -----------------------------------------------------
            % ���������������������˸�1/2����������ν��Ӱ��
            codeError = (sqrt(I_E * I_E + Q_E * Q_E) - sqrt(I_L * I_L + Q_L * Q_L)) / ...
                (sqrt(I_E * I_E + Q_E * Q_E) + sqrt(I_L * I_L + Q_L * Q_L));
            
            % ��·�˲�����ʱ��ʽ���Ǵ�Z��ת���õ������ز�����������
            codeNco = oldCodeNco + (tau2code/tau1code) * ...
                (codeError - oldCodeError) + codeError * (PDIcode/tau1code);
            oldCodeNco   = codeNco;
            oldCodeError = codeError;
            
            % ע��˴�Ӧ�Ǽ��š�����λ����ͬ��ʱӦ����E��L֧·�ź�������ȣ���
            % С��P֧·�ź����������������E֧·��������L֧·����ʱ�ɼ�������ʽ
            % �ɵ�codeError > 0����ʱ��·��Ϊ��������λ��ǰ�������źŵ�����λ�����
            % Ӧ���ͱ�����Ƶ�ʣ���΢����һ�ȡ������źš�
            codeFreq = settings.codeFreqBasis - codeNco;
            % codeFreq = settings.codeFreqBasis - codeNco + (carrFreq - settings.IF) / 1540;   % �ù�ʽΪ�ز��������뻷
            
            trackResults(channelNr).codeFreq(loopCnt) = codeFreq;

%% ��¼�źŸ��ٵĽ�� ----------------------
            % ��¼�����ļ�ָ���λ�ã�����ֵ�ĵ�λΪ���������������ֵ��Ϊ�˴�
            % ���ٻ���ȡ�۲�ֵ�õġ���ftell�ĵ�λ���ֽڣ��˴�Ҫע�ⵥλƥ��
            trackResults(channelNr).absoluteSample(loopCnt) = ftell(fid) / ...
                                    settings.dataFormat / settings.fileType;

            trackResults(channelNr).dllDiscr(loopCnt)       = codeError;
            trackResults(channelNr).dllDiscrFilt(loopCnt)   = codeNco;
            trackResults(channelNr).pllDiscr(loopCnt)       = carrError;
            trackResults(channelNr).pllDiscrFilt(loopCnt)   = carrNco;
            
            % ���ڻ�������ͼ���۲�E��P��L��֧·�ź������仯
            trackResults(channelNr).I_E(loopCnt) = I_E;
            trackResults(channelNr).I_P(loopCnt) = I_P;
            trackResults(channelNr).I_L(loopCnt) = I_L;
            trackResults(channelNr).Q_E(loopCnt) = Q_E;
            trackResults(channelNr).Q_P(loopCnt) = Q_P;
            trackResults(channelNr).Q_L(loopCnt) = Q_L;
            
            trackResults(channelNr).remCodePhase(loopCnt)   = remCodePhase;
            trackResults(channelNr).remCarrPhase(loopCnt)   = remCarrPhase;
            
        end % for loopCnt

        % �򵥵���Ϊ�ɹ����������źŵ�ͨ���ڸ��ٻ��ڶ��ɹ��������ź�
        % ������ʵӦ�ý����źŸ��ټ�⣬ʵʱ�ж��ź��Ƿ�ʧ��
        % ���ұȽ���
        trackResults(channelNr).status  = channel(channelNr).status;        
        
    end % if a PRN is assigned
end % for channelNr 

% �رս�����
close(hwb)
