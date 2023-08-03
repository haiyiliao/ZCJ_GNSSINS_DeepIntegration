function acqResults = acquisition_L1CA2(longSignal, settings)
%Function performs cold start acquisition on the collected "data". It
%searches for GPS signals of all satellites, which are listed in field
%"acqSatelliteList" in the settings structure. Function saves code phase
%and frequency of the detected signals in the "acqResults" structure.
%
%acqResults = acquisition(longSignal, settings)
%
%   Inputs:
%       longSignal    - 20 ms of raw signal from the front-end 
%       settings      - Receiver settings. Provides information about
%                       sampling and intermediate frequencies and other
%                       parameters including the list of the satellites to
%                       be acquired.
%   Outputs:
%       acqResults    - Function saves code phases and frequencies of the 
%                       detected signals in the "acqResults" structure. The
%                       field "carrFreq" is set to 0 if the signal is not
%                       detected for the given PRN number. 

% �������޷�Ӧ�Ա������䣬�Ҳ����þ�ȷ����

%% ��ʼ�� =========================================================
tempFreq = settings.samplingFreq;
rawSignal = longSignal;     % ������֮ǰ��Ƶ��
downratio = 1;              % ������������ʼ������û�н����������ֵΪ1
% �Ƿ�ʹ�ý�����
if settings.acqDownSample == 1
    downratio = settings.samplingFreq / settings.acqDownFreq;  % ����������
    longSignal = downsample(longSignal, downratio);
    settings.samplingFreq = settings.acqDownFreq;
end
signal0DC = rawSignal - mean(rawSignal);      % ���ھ�ȷ����

% һ��CA�����ڶ�Ӧ�Ĳ��������
samplesPerCode = round(settings.samplingFreq / ...
                        (settings.codeFreqBasis / settings.codeLength));

% ��������������ʱ�����У������޶�������ɻ���ʱ��������10ms����˱�Ȼ��һ��ʱ������û�б��ط�ת
signal1 = longSignal(1 : settings.acqnonCoIntime * settings.acqCoIntime * samplesPerCode);
signal2 = longSignal(settings.acqnonCoIntime * settings.acqCoIntime * samplesPerCode+1 : ...
                     2 * settings.acqnonCoIntime * settings.acqCoIntime * samplesPerCode);
 
% ������
ts = 1 / settings.samplingFreq;

% �ز�����λ
phasePoints = (0 : (settings.acqnonCoIntime * settings.acqCoIntime * samplesPerCode - 1)) * 2 * pi * ts;

% Ƶ��������Ԫ����
numberOfFrqBins = round(settings.acqSearchBand / settings.acqSearchStep) + 1;

% ���ݲ����ʺ���ɻ���ʱ������CA��
caCodesTable = makeCaTable(settings);   % �䳤�� = settings.acqCoIntime * samplesPerCode

%------------- ��ʼ���������ڴ洢������ ----------------------------------
% Ū�������ˣ����������
% �洢��������Ƶ�ʺ�����λ (һ������)
results = zeros(numberOfFrqBins, samplesPerCode); % ����λ�������ܻ���ʱ���Ӱ��

% �ز�Ƶ������
frqBins = zeros(1, numberOfFrqBins);

%--- acqResults�ṹ���ʼ�� ------------------------------------------------
acqResults.carrFreq     = zeros(1, 32);     % ���񵽵�Ƶ��
acqResults.codePhase    = zeros(1, 32);     % ���񵽵�����λ

acqResults.peakMetric   = zeros(1, 32);     % Correlation peak ratios of the detected signals

fprintf('(');

% ��ʼ������̣�ʹ�û���FFT�Ĳ�������λ�����㷨
for PRN = settings.acqSatelliteList

%% ���źŽ�����ز��� ======================================================   
    %---------- ��CA�����FFT���� ------------------------------------------
    caCodeFreqDom = conj(fft(caCodesTable(PRN, :)));
    
    for frqBinIndex = 1 : numberOfFrqBins       % Ƶ������
        
        % ����ʵ�źź͸��źŷֿ��������û�б�Ҫ���Ժ���̽����     
        acqRes1 = 0; acqRes2 = 0;       % ���ֱ�����ʼ����MATLAB�Դ��㲥���ƣ��Ὣ0��Ϊ0����
        
        % ����Ƶ�ʵ�Ԫ��
        frqBins(frqBinIndex) = settings.IF - (settings.acqSearchBand/2) + settings.acqSearchStep * (frqBinIndex - 1);
        
        for nonCoIntIndex = 1 : settings.acqnonCoIntime   % ����ɻ��ִ���
            if settings.fileType == 1  % ����ʵ�ź�
                
                % �����ز�
                sinCarr = sin(frqBins(frqBinIndex) * phasePoints((nonCoIntIndex-1)*settings.acqCoIntime*samplesPerCode+1: ...
                                                                 nonCoIntIndex*settings.acqCoIntime*samplesPerCode));
                cosCarr = cos(frqBins(frqBinIndex) * phasePoints((nonCoIntIndex-1)*settings.acqCoIntime*samplesPerCode+1: ...
                                                                 nonCoIntIndex*settings.acqCoIntime*samplesPerCode));

                % ��ɻ���
                I1      = sinCarr .* signal1((nonCoIntIndex-1)*settings.acqCoIntime*samplesPerCode+1: ...
                                                                 nonCoIntIndex*settings.acqCoIntime*samplesPerCode);
                Q1      = cosCarr .* signal1((nonCoIntIndex-1)*settings.acqCoIntime*samplesPerCode+1: ...
                                                                 nonCoIntIndex*settings.acqCoIntime*samplesPerCode);
                I2      = sinCarr .* signal2((nonCoIntIndex-1)*settings.acqCoIntime*samplesPerCode+1: ...
                                                                 nonCoIntIndex*settings.acqCoIntime*samplesPerCode);
                Q2      = cosCarr .* signal2((nonCoIntIndex-1)*settings.acqCoIntime*samplesPerCode+1: ...
                                                                 nonCoIntIndex*settings.acqCoIntime*samplesPerCode);

                % ��ʱ���ź�ת����Ƶ�� 
                IQfreqDom1 = fft(I1 + 1j*Q1) ./ length(I1);  % ��ֹ��ֵ����
                IQfreqDom2 = fft(I2 + 1j*Q2) ./ length(I2);
                    
                % Ƶ�ʳ˻��ȼ���ʱ����
                convCodeIQ1 = IQfreqDom1 .* caCodeFreqDom;
                convCodeIQ2 = IQfreqDom2 .* caCodeFreqDom;
                
            else  % �����ź�
                carr = exp(-1j * frqBins(frqBinIndex) * phasePoints((nonCoIntIndex-1)*settings.acqCoIntime*samplesPerCode+1: ...
                                                                 nonCoIntIndex*settings.acqCoIntime*samplesPerCode));
                IQ1 = carr .* signal1((nonCoIntIndex-1)*settings.acqCoIntime*samplesPerCode+1: ...
                                                                 nonCoIntIndex*settings.acqCoIntime*samplesPerCode);
                IQ2 = carr .* signal2((nonCoIntIndex-1)*settings.acqCoIntime*samplesPerCode+1: ...
                                                                 nonCoIntIndex*settings.acqCoIntime*samplesPerCode);
                                                             
                % ��ʱ���ź�ת����Ƶ��               
                IQfreqDom1 = fft(IQ1 ./ length(IQ1));  % ��ֹ��ֵ����
                IQfreqDom2 = fft(IQ2 ./ length(IQ2));
                    
                % Ƶ�ʳ˻��ȼ���ʱ����
                convCodeIQ1 = IQfreqDom1 .* caCodeFreqDom;
                convCodeIQ2 = IQfreqDom2 .* caCodeFreqDom;                
            end
            
            acqRes1 = acqRes1 + abs(ifft(convCodeIQ1)) .^ 2;   % �ڴ˴������ۼӲ��������ķ���ɻ��֣�abs()Ĩ����λ�����͵ķ����
            acqRes2 = acqRes2 + abs(ifft(convCodeIQ2)) .^ 2;          
        end  
      
        % �������ֵ�ϴ��һ��Ϊ����������Ϊֵ�ϴ��һ�������ܲ��漰���ط�ת
        if (max(acqRes1) > max(acqRes2))
            results(frqBinIndex, :) = acqRes1(1 : samplesPerCode);  % ��������ȡ��һ��CA�����ڼ���
        else
            results(frqBinIndex, :) = acqRes2(1 : samplesPerCode);
        end
    end

    
%% ��acqRes��Ѱ������ط�ֵ =========================================
    % ����źŲ���ɹ������һ��ֵӦ���Դ��ڵڶ���ֵ
    
    % Ѱ�Ҳ��񵽵�Ƶ��
    [~, frequencyBinIndex] = max(max(results, [], 2));
    
    % Ѱ�Ҳ��񵽵�����λ
    [peakSize, codePhase] = max(max(results));
    
    %--- Find 1 chip wide C/A code phase exclude range around the peak ----
    samplesPerCodeChip   = round(settings.samplingFreq / settings.codeFreqBasis);
    excludeRangeIndex1 = codePhase - samplesPerCodeChip;
    excludeRangeIndex2 = codePhase + samplesPerCodeChip;

    % ȥ����һ��ֵ�����Ĳ����㣬�̶�Ѱ�ҵڶ���ֵ
    if excludeRangeIndex1 < 2
        codePhaseRange = excludeRangeIndex2 : ...
                         (samplesPerCode + excludeRangeIndex1);
                         
    elseif excludeRangeIndex2 >= samplesPerCode
        codePhaseRange = (excludeRangeIndex2 - samplesPerCode) : ...
                         excludeRangeIndex1;
    else
        codePhaseRange = [1:excludeRangeIndex1, ...
                          excludeRangeIndex2 : samplesPerCode];
    end

    % Ѱ�ҵڶ���ֵ
    secondPeakSize = max(results(frequencyBinIndex, codePhaseRange));

    % �����һ��ֵ��ڶ���ֵ�ı�ֵ
    acqResults.peakMetric(PRN) = peakSize / secondPeakSize;
    
    % ��¼���񵽵�����λ
    if settings.acqDownSample == 1
        codePhase = (codePhase - 1) * downratio;  % ��ԭ��������֮ǰ������λ
    end
    acqResults.codePhase(PRN) = codePhase;
    
    % ���ֵ������ֵ����˵������ɹ����̶����о��������
    if (peakSize/secondPeakSize) > settings.acqThreshold      
        fprintf('%02d ', PRN);   % ��ʾ����ɹ���PRN��

%% Ƶ�ʾ�ȷ������ע���ʱ�Ĳ����ʱ�������Ƶ���ݵ���������
        samplesPerCode_findacq = round(tempFreq / ...
                        (settings.codeFreqBasis / settings.codeLength));
        ts_findacq = 1/tempFreq;
                    
        caCode = generateCAcode(PRN);
        codeValueIndex = floor((ts_findacq * (1:10*samplesPerCode_findacq)) / (1/settings.codeFreqBasis)); % ʹ��10ms���ȵ�����
        longCaCode = caCode((rem(codeValueIndex, 1023) + 1));     % ���ɳ���Ϊ10ms��CA��
        xCarrier = signal0DC(codePhase:(codePhase + 10*samplesPerCode_findacq-1)) .* longCaCode;   % ȥ��CA�룬ֻ�����ز�
        fftNumPts = 8*(2^(nextpow2(length(xCarrier))));
        
        if settings.IF <= 0
            fftxc = abs(fft(xCarrier, fftNumPts)) ./ fftNumPts;         
            fftxc = fftshift(fftxc);
            ffs = settings.samplingFreq;
            fff = -ffs/2 : ffs/fftNumPts : ffs/2 - ffs/fftNumPts;
            [~, fftMaxIndex] = max(fftxc); 
            acqResults.carrFreq(PRN)  = fff(fftMaxIndex);
        else
            fftxc = abs(fft(xCarrier, fftNumPts)) ./ fftNumPts;         
            uniqFftPts = ceil((fftNumPts + 1) / 2); % focus on freq between(0,pi), exclude (pi,2pi)
            [~, fftMaxIndex] = max(fftxc);       
            fftFreqBins = (0 : uniqFftPts-1) * tempFreq / fftNumPts; 
            acqResults.carrFreq(PRN)  = fftFreqBins(fftMaxIndex);
        end
        
                           
    else
        %--- No signal with this PRN --------------------------------------
        fprintf('. ');
    end   % if (peakSize/secondPeakSize) > settings.acqThreshold
    
end    % for PRN = satelliteList

%=========== ������̽��� ==================================================
fprintf(')\n');
settings.samplingFreq = tempFreq;    % �ָ�������
end
