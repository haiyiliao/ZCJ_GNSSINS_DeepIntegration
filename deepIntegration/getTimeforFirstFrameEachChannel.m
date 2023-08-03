function recvTimeforFirstFrameperChannel = getTimeforFirstFrameEachChannel(settings, firstFrameSamplePos)
%% ����ÿ��ͨ���״γ���֡ͷ��ʱ���Ӧ�ı��ؽ��ջ�ʱ�����ֵ
%
% �������: 
%        - settings: ���ջ���ز���
%        - firstFrameSamplePos: ��ͨ���״γ���֡ͷʱ��Ӧ�Ĳ�������
%
% �������:?
%        - recvTimeforFirstFrameperChannel: ��ͨ���״γ���֡ͷʱ���ջ��ı���ʱ�����ֵ
%
% -------------------------------------------------------------------------
%%
numActChnList = length(firstFrameSamplePos);
recvTimeforFirstFrameperChannel = zeros(1, numActChnList);
maxSamplePos = max(firstFrameSamplePos);

for ii = 1 : numActChnList
    remTime = (maxSamplePos - firstFrameSamplePos(ii) ) / settings.samplingFreq;
    recvTimeforFirstFrameperChannel(ii) = settings.recvTime - remTime;
end

end