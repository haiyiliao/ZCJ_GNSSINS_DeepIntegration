% ZCJ�ع�GNSS_SDR��Ŀ�����������е�����BUG

clear; close all; 
%%
format ('compact');
format ('long', 'g');

%-------- ���һЩ�ļ��е�����·���� ---------------------------------------
addpath include             % ��һЩ�Ӻ�����������
addpath geoFunctions        % һЩ�͵�����ص��Ӻ���
addpath acquire_zcj         % �źŲ���
addpath track_zcj           % �źŸ��ٺ���
addpath PVT                 % ��λ
addpath deepIntegration     % ������ϵ���ʵ��

%% ��ʼ�� ==========================================================
disp ('Starting processing...');

settings = initSettings();
[fid, message] = fopen(settings.fileName, 'rb');

% �����ļ��ɹ�����
if (fid > 0)
    
    % ���ļ�ָ���ƶ�����ʼλ�ã�ע��ڶ��������ĵ�λ���ֽ�
    fseek(fid, settings.skipNumberOfSamples * settings.dataFormat * settings.fileType, 'bof');

%% Acquisition ============================================================

    % ��ʼ������̣�����������û��ǿ�������Ļ�
    if ((settings.skipAcquisition == 0) || ~exist('acqResults', 'var'))
        
        % һ��CA�����ڶ�Ӧ�Ĳ��������
        samplesPerCode = round(settings.samplingFreq / ...
                           (settings.codeFreqBasis / settings.codeLength));
        
        % ��ȡ�������ڲ���. ʹ�ó���Ϊ20ms���������ھ�ȷ����(��ȷ������һ����
        % ���Ǳ���ģ�Ӧ����ʵ��Ӧ�ý��п���)
        data = fread(fid, 20 * samplesPerCode * settings.fileType, settings.dataType)';
        if settings.fileType == 2
            dataI = data(1:2:end);
            dataQ = data(2:2:end);
            % data  = 1 * dataI + 0 * dataQ;   % using I only 
            data  = 1 * dataI + 1j * dataQ;  % using IQ 
        end

        %-------- ��ʼ������� ---------------------------------------------
        disp ('   Acquiring satellites...');
        
        notUsingFineFreqAcq = 1;                     % ��ʹ��Ƶ�ʾ�ȷ����
        if notUsingFineFreqAcq == 1
            acqResults = acquisition_L1CA1(data, settings);   % ���㷨�޷��ֿ����ط�ת����ʹ�þ����񷽷������������źŲ���
        else
            acqResults = acquisition_L1CA2(data, settings);   % ���㷨�޷��ֿ����ط�ת��ʹ�þ����񷽷������������źŲ���
        end
        
        plotAcquisition(acqResults, settings);
        clear data dataI dataQ
    end

%% ������õ��Ľ�����ó�ͨ���ĳ�ʼ״̬ ===============================
    if (any(acqResults.carrFreq))   % �����ͨ������ɹ������ͨ����ʼ��
        channel = preRun(acqResults, settings);    % ���ò��񵽵����ݳ�ʼ��ͨ���ṹ��
        showChannelStatus(channel, settings);
    else
        % û��⵽�κ������ź�
        disp('No GNSS signals detected, signal processing finished.');
        trackResults = [];
        return;
    end

%% �źŸ��� =========================================================
    startTime = now;
    disp (['   Tracking started at ', datestr(startTime)]);
    
    % ���ڸ������ȵ�����(��settings.msToProcess����)�����źŸ���
    % ���ٷ�ʽΪ���ͨ�����٣���ͨ��֮�䲻�ǲ��е�
    % ����д�����ָ��ٺ���
    
    % GNSS_SDR�ĸ��ٺ�������ʹ��1ms��ɻ��֣���˿��Բ����Ǳ���ͬ��������
    % [trackResults, channel] = tracking(fid, channel, settings);
    
    % �����뻷�������ز�����PLL��·�˲������鱾���ź���ͼ��д������ʹ��1ms��ɻ���
    % [trackResults, channel] = trackpll2nd(fid, channel, settings);  
    
    % �����뻷�������ز�����PLL��·�˲������鱾���ź���ͼ��д������ʹ��1ms��ɻ���
    % [trackResults, channel] = trackpll3rd(fid, channel, settings);
    
    % �����뻷�������ز�����PLL��·�˲���������һ��д������ʹ��1ms��ɻ���
    % [trackResults, channel] = trackpll3rd2(fid, channel, settings);
    
    % �����뻷��һ��FLL��������PLL����ʹ��1ms��ɻ��֣�����gnss_sdrlib���C���Դ���
    % �ú�������ȷ���д���֤,��Ȼ�����ǶԵ�(doge),��ʹ��1ms��ɻ���
    % isFLL = 1, ��Ͽ�PLL��Ϊ��PLL������ΪFLL����PLL
    isFLL = 0; [trackResults, channel] = trackfll1stpll2nd(fid, channel, settings, isFLL);
    
    % �����뻷��һ��FLL��������PLL����ʹ��1ms��ɻ��֣�����gnss_sdrlib���C���Դ���
    % �ú�������ȷ���д���֤,��Ȼ�����ǶԵ�(doge),��ʹ��1ms��ɻ���
    % ��ȫ�����ź���ͼ��д��
    % isFLL = 1, ��Ͽ�PLL��Ϊ��PLL������ΪFLL����PLL
    % [trackResults, channel] = trackfll1stpll2nd2(fid, channel, settings, isFLL);
    
    % �����뻷������FLL��������PLL����ʹ��1ms��ɻ��֣�����gnss_sdrlib���C���Դ���
    % �ú�������ȷ���д���֤,��Ȼ�����ǶԵ�(doge),��ʹ��1ms��ɻ���
    % ��ȫ�����ź���ͼ��д��
    % isFLL = 1, ��Ͽ�PLL��Ϊ��PLL������ΪFLL����PLL
    % [trackResults, channel] = trackfll2ndpll3rd(fid, channel, settings, isFLL);
    
    % �ر������ļ�
    fclose(fid);
    
    disp(['   Tracking is over (elapsed time ', ...
                                        datestr(now - startTime, 13), ')'])     

    % ���ٻ�ķѺܳ�ʱ�䣬���ٽ����󽫸��ٽ���洢������
    disp('   Saving Acq & Tracking results to file "trackingResults.mat"')
    save('trackingResults', ...
                      'trackResults', 'settings', 'acqResults', 'channel');                  

%% ��λ ============================================================
    disp('   Calculating navigation solutions...');
    [navSolutions, eph, subFrameStart, TOW] = postNavigation_zcj(trackResults, settings);
    disp('   Processing is complete for this data block');
    
%% չʾ��� ===================================================
    disp ('   Ploting results...');
    if settings.plotTracking
        plotTracking(1:settings.numberOfChannels, trackResults, settings);
    end

%    plotNavigation(navSolutions, settings);

    disp('Post processing of the signal is over.');

else
    % �����ļ�����ʧ��
    error('Unable to read file %s: %s.', settings.fileName, message);
end 
