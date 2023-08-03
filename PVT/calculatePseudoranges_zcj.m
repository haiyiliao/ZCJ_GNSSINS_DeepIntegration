function [pseudoranges, transmitTimeatSat, Doppler] = calculatePseudoranges_zcj(trackResults, ...
                                                msOfTheSignal, ...
                                                activeChnList, settings, TOW)

%% ���״ζ�λʱ������Ϊ���������֡������ջ���ʱ��
SampleNum = zeros(1, length(activeChnList));
Doppler   = zeros(1, length(activeChnList));

for i = 1 : length(activeChnList)
    k = activeChnList(i);
    SampleNum(i) = trackResults(k).absoluteSample(msOfTheSignal(k));
end
maxSampleNum = max(SampleNum);  % ��������ź�λ�ö�Ӧ�Ĳ���������

num_Cyclic = zeros(1, length(activeChnList));   % ������֡֡ͷ�����������֡ͷ֮���CA��������
remSapmle = zeros(1, length(activeChnList));    % ����һ���ܵ�ʣ��Ĳ�������
codePhaseTao = zeros(1, length(activeChnList)); % ����һ���ܵ����һ���������Ӧ������λ
remTime = zeros(1, length(activeChnList));      % ��Ӧ�ķ���ʱ��
j = 1;
for i = 1 : length(activeChnList)
    k = activeChnList(i);
    while trackResults(k).absoluteSample(msOfTheSignal(k) + j) < maxSampleNum
        j = j + 1;
    end
    num_Cyclic(i) = j - 1;
    j = 1;
    remSapmle(i)    = maxSampleNum - trackResults(k).absoluteSample(msOfTheSignal(k) + num_Cyclic(i));
    
    Doppler(i)      = trackResults(k).carrFreq(msOfTheSignal(k) + num_Cyclic(i)) - settings.IF;

    remCodePhase    = trackResults(k).remCodePhase(msOfTheSignal(k) + num_Cyclic(i));
    codeFreq        = trackResults(k).codeFreq(msOfTheSignal(k) + num_Cyclic(i));
    codePhaseStep   = codeFreq / settings.samplingFreq;
    codePhaseTao(i) = remCodePhase + codePhaseStep * ( remSapmle(i) - 1 );
    remTime(i)      = num_Cyclic(i) * 1e-3 + codePhaseTao(i) / 1023 * 1e-3;   % ��λ: s
end                                            

%%
travelTime = zeros(1, length(activeChnList));               
channelList = reshape(activeChnList, 1, length(activeChnList));
for channelNr = 1:length(channelList)
    
    %--- �����źŴ���ʱ�� -----------------------------------------    
    travelTime(channelNr) = settings.recvTime - (TOW + remTime(channelNr));   % p = c (tr - tx)
end

pseudoranges = travelTime .* settings.c;     % α��
transmitTimeatSat = TOW + remTime;

end

