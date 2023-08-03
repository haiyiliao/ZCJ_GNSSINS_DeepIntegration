function settings = initSettings()
% Functions initializes and saves settings. 
%
% All settings are described inside function code.
%
% settings = initSettings()
%
%   Inputs: none
%
%   Outputs:
%       settings     - Receiver settings (a structure). 

%% Processing settings ====================================================
settings.msToProcess          = 17000;        % �ܵ��źŴ���ʱ�䳤�� [ms]
settings.numberOfChannels     = 6;            % ���ջ�ͨ���� (��Ƶ�����ݸ�һ��)
settings.skipNumberOfSamples  = 0;            % �źŴ������ʼ�� [sample number]

%% Raw signal file name and other parameter ===============================
settings.fileName           = ...
   'E:\zcj_masterDegree_code_assemble\test_522_B1C_4MSpan.bin';
settings.dataType           = 'int16';
settings.IF                 = 0e6;      % [Hz]
settings.samplingFreq       = 5e6;     % [Hz]
settings.codeFreqBasis      = 1.023e6;  % [Hz]
settings.fileType           = 2;        % 2 for IQ; 1 for I only
settings.dataFormat         = 2;        % 2 for int16; 1 for int8
settings.codeLength         = 1023;


%% Acquisition settings ===================================================
settings.skipAcquisition    = 0;        % 0, ����; 1, �����������
settings.acqSatelliteList   = 1:32;     % �����б� [PRN numbers]
settings.acqSearchBand      = 20e3;     % Ƶ��������Χ [Hz]������ƵΪ���ģ�������Hz
settings.acqSearchStep      = 500;      % Ƶ���������� [Hz]

settings.acqThreshold       = 2.5;      % �������ޣ��벶�񷽷��йأ�����Ҫ����ʵ���������ѡ��

settings.acqDownSample      = 0;        % 0, ����ʱ��������; 1, ����ʱ������
settings.acqDownFreq        = 3e6;      % ���ڲ��������˵�����ʵ����Ͳ���������߲����ٶȡ������ܵ������ʵ�2����
                                        % Ϊ�˷��㣬�����������Ƶ������Ϊԭ�����ʵ�������֮1
                                        % ��ȷ����ʹ�õ���FFT���������ǲ����ʱ��������Ƶ��2��
                                        % ��������Ӱ�������Ƶ�ʵļ��㣬��Ӱ�����Ƶ�ʵļ���

% ����CA����˵������δʵ��λͬ��������ɻ���ʱ��ӦС��10ms
settings.acqCoIntime        = 1;        % �������ɻ���ʱ�� [ms]
settings.acqnonCoIntime     = 1;        % ����ķ���ɻ��ִ��� [times]   
if settings.acqCoIntime * settings.acqnonCoIntime >= 10 || settings.acqCoIntime <= 0
    error('Too long Integration Time or Wrong acqCoIntime Time ! ');
end  


%% Tracking loops settings ================================================
% ��������PLL��DLL�Ļ�·��������һ��

% �����Ƕ����뻷 ----------------------------------------------------------------- 
settings.dllDampingRatio         = 0.7;
settings.dllNoiseBandwidth       = 2;       % [Hz]

settings.dllCorrelatorSpacing    = 0.5;     % [chips]

% �ز���, ���Ƕ��׺����׵�������� -------------------------------------------------         
settings.pllNoiseBandwidth       = 25;       % �������׼�����PLL��˵������������ѡ���Է����ֲ��ȶ����� [Hz]
settings.pllLoopGain             = 1;        % ��·���棬�ڹ��������ɵ�·��Ƽ���õ�������������
settings.pllDampingRatio         = 0.7;

% ����CA����˵����ɻ���ʱ�� settings.trkCoIntime ӦС��20ms
settings.trkCoIntime             = 2;       % ���ٵ���ɻ���ʱ�� [ms]
settings.trknonCoIntime          = 2;       % ���ٵķ���ɻ��ִ��� [times]

% FLL
settings.fllNoiseBandwidth       = 17;
settings.fllLoopGain             = 1;

%% Navigation solution settings ===========================================
settings.navSolPeriod       = 500;          % ��λ���� [ms]

settings.elevationMask      = 10;           % ��ֹ����[degrees 0 - 90]

% ����/���ö�����У��
settings.useTropCorr        = 0;            % 0 - Off
                                            % 1 - On

%% Plot settings ==========================================================
% �Ƿ���ʾ�źŸ��ٵ�Ч��
settings.plotTracking       = 1;            % 0 - Off
                                            % 1 - On

%% Constants ==============================================================
settings.c                  = 299792458;    % ���� [m/s]
settings.startOffset        = 80.000;       % [ms] Initial sign. travel time
