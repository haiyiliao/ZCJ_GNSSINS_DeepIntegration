glvs
ts = 0.01;       % sampling interval
avp0 = [[0;0;0]; [0;0;0]; glv.pos0]; % init avp
% trajectory segment setting �켣���£�  
% ��ʾЭ����ת�䣬�Ⱥ��������ת4s��������ת45s,�����������ת4s.���ǵ��˺�������
%1.ֱ���˶�(27s)��  ��ֹ20s;     5m/s^2���ٶȼ���5s;    25m/s�ٶ�����ֱ��2s;
%2."8"����Բ���˶���52s)����ʾЭ����ת�䣬�Ⱥ��������ת4s��20��/s ת�Ǳ仯����Բ���˶��������������ת4s.  
%�����ǵ��˺�����������ʾЭ����ת�䣬�Ⱥ��������ת4s��20��/s ת�Ǳ仯����Բ���˶��������������ת��s.
%3.�����������£�25m/s�ٶ�����ֱ��2s,7m/s^2���ٶȼ���3s;46m/s����ֱ���˶�2s;5������5s������2s��5������5s;
%4.�����˶���
%5.
xxx = [];
seg = trjsegment(xxx, 'init',         0);   %��ʾ�켣�ṹ����ĳ�ʼ��
seg = trjsegment(seg, 'uniform',      20);  %��ʾ������һ״̬20s
seg = trjsegment(seg, 'accelerate',   5, xxx, 5);
seg = trjsegment(seg, 'uniform',      2); 
seg = trjsegment(seg, '8turn', [], 20, [], 4);
% seg = trjsegment(seg, '8turn', [], w, [], rolllasting); 
seg = trjsegment(seg, 'uniform',      2);
seg = trjsegment(seg, 'accelerate',   7, xxx, 3);
seg = trjsegment(seg, 'uniform',      2);
seg = trjsegment(seg, 'climb',        5, 5, xxx, 2);
seg = trjsegment(seg, 'uniform',      1);
seg = trjsegment(seg, 'coturnright', 3, 30, [], 1); 
seg = trjsegment(seg, 'uniform',      1);
seg = trjsegment(seg, 'turnright', 3, 30);
% seg = trjsegment(seg, 'coturnright', 3, 30, [], 1); 
seg = trjsegment(seg, 'uniform',      1);
seg = trjsegment(seg, 'descent', 2, 30, [], 2);
seg = trjsegment(seg, 'uniform',      1);
seg = trjsegment(seg, 'deaccelerate', 3, [], 10);
seg = trjsegment(seg, 'uniform',      1);
seg = trjsegment(seg, 'coturnright', 3, 30, [], 1); 
seg = trjsegment(seg, 'coturnleft', 3, 30, [], 1);
seg = trjsegment(seg, 'accelerate',   3, xxx, 12);
seg = trjsegment(seg, 'accelerate',   3, xxx, 15);
seg = trjsegment(seg, 'uniform',      5);
seg = trjsegment(seg, 'turnright', 3, 30);
seg = trjsegment(seg, 'deaccelerate', 1, [], 18);
seg = trjsegment(seg, 'uniform',      1);

trj_sc522  = trjsimu(avp0, seg.wat, ts, 1);
trjfile('trj_sc522.mat', trj_sc522);
insplot(trj_sc522.avp);
imuplot(trj_sc522.imu);

%%
figure(101); scatter3(trj_sc522.avp(:, 7), trj_sc522.avp(:, 8), trj_sc522.avp(:, 9));
title("trajectory in ENU frame");

