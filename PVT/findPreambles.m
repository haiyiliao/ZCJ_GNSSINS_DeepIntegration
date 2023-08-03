function [firstSubFrame, activeChnList, firstSubFrameSampleNum] = findPreambles(trackResults, settings)
% findPreambles finds the first preamble occurrence in the bit stream of
% each channel. The preamble is verified by check of the spacing between
% preambles (6sec) and parity checking of the first two words in a
% subframe. At the same time function returns list of channels, that are in
% tracking state and with valid preambles in the nav data stream.
%
%[firstSubFrame, activeChnList] = findPreambles(trackResults, settings)
%
%   Inputs:
%       trackResults    - output from the tracking function
%       settings        - Receiver settings.
%
%   Outputs:
%       firstSubframe   - the array contains positions of the first
%                       preamble in each channel. The position is ms count 
%                       since start of tracking. Corresponding value will
%                       be set to 0 if no valid preambles were detected in
%                       the channel.
%       activeChnList   - list of channels containing valid preambles

%--------------------------------------------------------------------------

% ֡ͬ����һ��Ҫ��һ��ʼ�ͽ��С����ڸ��ٻ������������տ�ʼ�ļ������ݱ���������
% �ϸߡ���˿����Ӻ�һ��ʱ���ٽ���֡ͬ���������˴����Ը����⡣
searchStartOffset = 0;

% ���ڴ洢֡ͬ�����
firstSubFrame = zeros(1, settings.numberOfChannels);

% ֡ͬ����
preamble_bits = [1 -1 -1 -1 1 -1 1 1];

% ��֡ͬ�����ϲ��������ڱ����̽�����1ms��ɻ��֣����һ�����ݱ��ذ���20��CA��
preamble_ms = kron(preamble_bits, ones(1, 20));

% ȥ��δ��ʵ���źŸ��ٵ�ͨ��
activeChnList = find([trackResults.status] ~= '-');

% ���Լ�����ı�������һ��������
firstSubFrameSampleNum = zeros(1, settings.numberOfChannels);

% ��ʼ֡ͬ������
for channelNr = activeChnList

%% �����ݱ��غ�֡ͬ������л���� ================================
    % ��ȡ���ݱ���
    bits = trackResults(channelNr).I_P(1 + searchStartOffset : end);   % �Ӹ��ٻ���I_P�����

    % ��ֵ�� 
    bits(bits > 0)  =  1;
    bits(bits <= 0) = -1;

    % �����
    tlmXcorrResult = xcorr(bits, preamble_ms);   % xcorr between data bits stream and preamble bits

%% Ѱ�ҿ��ܵ�֡ͷλ�� ===============================================
    clear index
    clear index2

    xcorrLength = (length(tlmXcorrResult) +  1) /2;

    %--- Ѱ�ҿ��ܵ�֡ͷλ�� ------------------------
    index = find(...
        abs(tlmXcorrResult(xcorrLength : xcorrLength * 2 - 1)) > 153)' + ...
        searchStartOffset;   % �������֡ͬ���룬�����ֵӦΪ160�����ǵ����ܴ������룬��˽�����ֵ����Ϊ153

%% ����ÿ������֡ͬ�����λ�� ========================================
    % Ѱ���״γ���֡ͷ��λ��
    for i = 1 : size(index) 

        %--- Find distances in time between this occurrence and the rest of
        %preambles like patterns. If the distance is 6000 milliseconds (one
        %subframe), the do further verifications by validating the parities
        %of two GPS words      
        index2 = index - index(i);  % each matched pattern has 6000ms interval

        if (~isempty(find(index2 == 6000, 1))) % ֡ͷÿ6000ms����һ��

            %=== Re-read bit vales for preamble verification ==============
            % Preamble occurrence is verified by checking the parity of
            % the first two words in the subframe. Now it is assumed that
            % bit boundaries a known. Therefore the bit values over 20ms are
            % combined to increase receiver performance for noisy signals.
            % in Total 62 bits mast be read :
            % 2 bits from previous subframe are needed for parity checking;
            % 60 bits for the first two 30bit words (TLM and HOW words).
            % The index is pointing at the start of TLM word.
            bits = trackResults(channelNr).I_P(index(i)-40 : ...
                                               index(i) + 20 * 60 -1)'; % ��ֵ���������ź����ƺ���ɻ���ʱ���й�

            %--- Combine the 20 values of each bit ------------------------
            bits = reshape(bits, 20, (size(bits, 1) / 20));
            bits = sum(bits);

            % Now threshold and make it -1 and +1 
            bits(bits > 0)  = 1;
            bits(bits <= 0) = -1;

            %--- Check the parity of the TLM and HOW words ----------------
            % �ܷ�ͨ����żУ��
            if (navPartyChk(bits(1:32)) ~= 0) && ...
               (navPartyChk(bits(31:62)) ~= 0)
                % Parity was OK. Record the preamble start position. Skip
                % the rest of preamble pattern checking for this channel
                % and process next channel. 
                
                firstSubFrame(channelNr) = index(i);
                break;    
            end % if parity is OK ...
            
        end % if (~isempty(find(index2 == 6000)))
    end % for i = 1:size(index)

    % Exclude channel from the active channel list if no valid preamble was
    % detected
    if firstSubFrame(channelNr) == 0
        
        % Exclude channel from further processing. It does not contain any
        % valid preamble and therefore nothing more can be done for it.
        activeChnList = setdiff(activeChnList, channelNr);

        disp(['Could not find valid preambles in channel ', ...
                                                  num2str(channelNr),'!']);
    else    
        firstSubFrameSampleNum(channelNr) = trackResults(channelNr).absoluteSample(firstSubFrame(channelNr));
    end
    
end % for channelNr = activeChnList

end