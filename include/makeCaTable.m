function caCodesTable = makeCaTable(settings)
%Function generates CA codes for all 32 satellites based on the settings
%provided in the structure "settings". The codes are digitized at the
%sampling frequency specified in the settings structure.
%One row in the "caCodesTable" is one C/A code. The row number is the PRN
%number of the C/A code.
%
%caCodesTable = makeCaTable(settings)
%
%   Inputs:
%       settings        - receiver settings
%   Outputs:
%       caCodesTable    - an array of arrays (matrix) containing C/A codes
%                       for all satellite PRN-s


%---------- һ��CA�����ڶ�Ӧ�Ĳ�������� -----------------------------------
samplesPerCode = round(settings.samplingFreq / ...
                           (settings.codeFreqBasis / settings.codeLength));

%---------- �洢�ϲ������CA�� ---------------------------------------------
caCodesTable = zeros(32, settings.acqCoIntime * samplesPerCode);
 
ts = 1 / settings.samplingFreq;   % �������� [s]
tc = 1 / settings.codeFreqBasis;  % CA����Ƭ����, Լ977.5ns
 
%=== ��ʼ����CA�� ...
for PRN = 1:32
    %------------ ����CA�� ------------------------------------------------
    caCode = generateCAcode(PRN);  % ˫����
    for ii = 1 : settings.acqCoIntime - 1
        caCode = [caCode, caCode(1:1023)];
    end
  
    %======= �ϲ��� =======================================================
    
    %--- Make index array to read C/A code values -------------------------
    % The length of the index array depends on the sampling frequency -
    % number of samples per millisecond (because one C/A code period is one
    % millisecond).
    codeValueIndex = ceil((ts * (1 : settings.acqCoIntime * samplesPerCode)) / tc);
    
    %--- Correct the last index (due to number rounding issues) -----------
    codeValueIndex(end) = settings.acqCoIntime * 1023;
    
    %--- Make the digitized version of the C/A code -----------------------
    % The "upsampled" code is made by selecting values form the CA code
    % chip array (caCode) for the time instances of each sample.
    caCodesTable(PRN, :) = caCode(codeValueIndex);
    
end 

end