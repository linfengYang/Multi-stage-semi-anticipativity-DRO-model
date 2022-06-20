%%  TS_UCC_DRO  by yy 2022.04.10

FileName_SCUC = 'data/SCUC6.txt';
FileName_Wind = 'data\Wind_power.xlsx';

SCUC_data = ReadDataSCUC(FileName_SCUC);
Wind_data = ReadWindData(SCUC_data,FileName_Wind);

% T = SCUC_data.totalLoad.T;  % ʱ����T
T = 12;  % ʱ����T
G = SCUC_data.units.N;      % �����������
N = SCUC_data.baseparameters.busN;  % �ڵ�����
W = SCUC_data.Wind.wind_Number; % ���������
M = size(Wind_data{1,1},2); % ��������
Gbus = SCUC_data.units.bus_G; % ����������ڵ��
Wbus = SCUC_data.Wind.wind_Node; % ������ڵ��
Dbus = SCUC_data.busLoad.bus_PDQR; % ���ؽڵ��
Pramp = SCUC_data.units.ramp; %����Լ��
Pstart = 0.5 * SCUC_data.units.PG_up; %������Լ��
Pshut = SCUC_data.units.PG_up; %�ػ���Լ�� 
Pup = SCUC_data.units.PG_up; %�����Ͻ�
Plow = SCUC_data.units.PG_low; %�����½�
Ton = SCUC_data.units.T_on; %��С����ʱ��
Toff = SCUC_data.units.T_off; %��С�ػ�ʱ��
L = 4; %�����Ĳ������������Ի��������
fa = SCUC_data.units.alpha; %������ó�����
fb = SCUC_data.units.beta; %�������һ����
fc = SCUC_data.units.gamma; %������ö�����
Ccold = SCUC_data.units.start_cost*2; %����������
Chot = SCUC_data.units.start_cost; % ����������
Tcold = min(max(Toff,1),T); %������ʱ��
Lup = 0.3*ones(N,1); % �����и��Ͻ�
Llow = 0*ones(N,1); %�����и��½�

% �γ�ֱ������ϵ������B
type_of_pf = 'DC';
Y = SCUC_nodeY(SCUC_data,type_of_pf);
B = -Y.B; %��Ϊ��ֱ������ ����B�����˵��� ֻ���ǵ翹

u0 = zeros(G,1); %�����ʼ״̬��Ŀǰ���趼�ǹػ�
T0 = zeros(G,1); %�����ʼʱ���迪����ػ�ʱ����
P0 = zeros(G,1); %��Ӧ��ʼ����ҲΪ0
U0 = zeros(G,1); 
L0 = zeros(G,1); 
tao0 = Toff+Tcold+1; %��������Ҫʱ�䣿

for index = 1:G
    mid_u = min(T,u0(index) * (Ton(index) - T0(index)));
    mid_l = min(T,(1-u0(index)) * (Toff(index) + T0(index)));
    U0(index) = max(0,mid_u);
    L0(index) = max(0,mid_l);
end

all_branch.I = [ SCUC_data.branch.I; SCUC_data.branchTransformer.I ]; % ����֧·��� ǰ��֧·��� ���Ǳ�ѹ��֧·���
all_branch.J = [ SCUC_data.branch.J; SCUC_data.branchTransformer.J ]; % ����֧·�յ�
all_branch.P = [ SCUC_data.branch.P; SCUC_data.branchTransformer.P ]; % ֧·��������

% ���� uncertainty set
PW = []; % �������������ϵ�һ��������У�ÿ�а��ȱ�t��i����
for i = 1:W
    PW = [PW; Wind_data{1,i}];
end
PW = [PW(1:T,:);PW(24+1:24+T,:)];
% for i = 1:W
%     PW = [PW; 0.05*ones(24,30)];
% end
% ���������ֵ
PW_miu = zeros(W*T,1);
for i = 1:M
    PW_miu = PW_miu + PW(:,i);
end
PW_miu = PW_miu / M;
% ���ƫ��
VW = zeros(W*T,M);
for j = 1:M
    VW(:,j) =  PW(:,j) - PW_miu;
end
VW_positive =  max(VW,[],2);
VW_negative =  min(VW,[],2);
% ksi ֧�ż�
ksi_positive = [1;VW_positive];
ksi_negative = [1;VW_negative];
% end of ���� uncertainty set

% non-linear decision rule
bN = 3; % �ֶ���
bpN = bN-1; % �ϵ���
bp = zeros(bN - 1,1); % �ȷֵ�����
kl = 1+bN; %һ��ksi��ά��
verts = []; % set of vertices
for t = 1:T
    for i = 1:W
        step = (VW_positive((t-1)*W+i) - VW_negative((t-1)*W+i)) / bN; %����ÿ�����䳤��
        bp = linspace(VW_negative((t-1)*W+i)+ step,VW_positive((t-1)*W+i)-step,bN-1)'; %��[a+s,b-s]�м�����ȡ�ȷֵ㣬��Ϊlinspace����ֻ���������
        verts = [verts, vers_nonb(bN,bp,VW_positive((t-1)*W+i),VW_negative((t-1)*W+i))];
    end
end
verts_nonksi = verts(2:4,:);
vN = length(verts)/(W*T); %�����
% verts = [ones(2*bN,(bN+1)*W), verts];
% end of non-linear decision rule

% ������ksi�����ߴ���
for m = 1:M
    ksi = VW(:,m);
    ksi_hat = [];
    ksi_hat2 = [];
    ksi_wan_now = [];
    for t = 1:T
        for i = 1:W
            step = (VW_positive((t-1)*W+i) - VW_negative((t-1)*W+i)) / bN; %����ÿ�����䳤��
            bp = linspace(VW_negative((t-1)*W+i)+ step,VW_positive((t-1)*W+i)-step,bN-1)'; %��[a+s,b-s]�м�����ȡ�ȷֵ㣬��Ϊlinspace����ֻ���������
            bp = [VW_negative((t-1)*W+i);bp;VW_positive((t-1)*W+i)];
            ksi_hat = L_hat(ksi((t-1)*W+i),bN,bp);
            ksi_hat2 = [ksi_hat2; L_hat(ksi((i-1)*T+t),bN,bp)];
            ksi_wan_now = [ksi_wan_now;ksi((t-1)*W+i);ksi_hat];
        end
    end
%     ksi_wan{m} = [ones(T,1); ones(T,1); ksi_hat; ksi_tine]; %��ksi_hat0;ksi_tine0;ksi_hat;ksi_tine����
    ksi_wan{m} = [ ones(T,1);ones(T,1);ksi_wan_now]; %��ksi0;ksi_hat0;ksi_tine0;ksi;ksi_hat;ksi_tine����
    ksi_wan2{m} = [ ksi_hat2]; %��ksi_hat;ksi_tine����
end
% end of ������ksi�����ߴ���

% ����wassersteinģ����
% eta = 0.95; %�������Ŷ�
% rho = sdpvar(1); %ģ�����뾶
% sum_C = 0;
% for i = 1:M
%     mid = PW(:,i) - PW_miu;
%     mid = rho * norm(mid,1)^2;
%     mid = exp(mid);
%     sum_C = sum_C + mid;
% end
% sum_C = sum_C / M;
% obj_C = 1 + log(sum_C);
% Constraints_C =  rho >= 0;
% Objective_C = 2 *  ( ((1 / (2 * rho)) * obj_C) ^(1/2) );
% options_C = sdpsettings('verbose',0,'debug',1,'savesolveroutput',1);%, 'fmincon.TolX',1e-4
% sol_C = optimize(Constraints_C,Objective_C,options_C);
% C = sol_C.solveroutput.fmin;
% mid_eps = log( 1 / (1-eta));
% mid_eps = mid_eps / M;
% eps = C * sqrt(mid_eps);
% % end of ����wassersteinģ����
eps = 4.5;
% �����͹��
% �������Ͻ������ verts

% end of �����͹��

%����ksi�����ܳ���
leng_k = 0;
for k = 1:T
    leng_k = leng_k+k;
end
%end of ����ksi����


% ����Լ��
% ������������ ÿ��ʱ�α�������ͬ�����õ�ʱ����
YG = sdpvar(G,T+W*bN*leng_k); %��������������߱�����ϵ������Y0,�ֶΣ������飬ʱ������
Ytheta = sdpvar(N,T+W*bN*leng_k); %�ڵ���Ǿ��߱�����ÿ���ڵ㶼��theta����ֹ������ڵ��У�������N��
Yz = sdpvar(G,T+W*bN*leng_k); % ��������������þ��߱���
YS = sdpvar(G,T+W*bN*leng_k); % �������鿪�����þ��߱���
YPw = sdpvar(W,T+W*bN*leng_k); %W�У�W��������
Yl = sdpvar(N,T+W*bN*leng_k); %�и��ؾ��߱���
% ���ͱ������þ��߹�����
% ��ȡֵΪ0��1binary����
Xu = binvar(G,T); %����״̬���߱���
Xs = binvar(G,T); %�����������߱���
Xd = binvar(G,T); %�ػ��������߱���

% ��ʼԼ������
cons = [];

% �ο��ڵ�
%ÿ��ģ�Ͷ�ֻ�趨��һ���ڵ�Ϊ�ο��ڵ㣿
Ytheta(1,:) = zeros(1,T+W*bN*leng_k); %ÿ���ڵ㶼��theta����ֹ������ڵ��У�������N��
% end of �ο��ڵ�

% ��ʼ״̬����
for g = 1:G % �����˿�ʼ���ǹػ����������ﱣ�ֹػ�״̬��û���ǳ�ʼ�ǿ������
    for t = 1:(U0(g)+L0(g))
        Xu(g,t) = 0; %Xu����
    end
end
% end of ��ʼ״̬����

% ����ʽԼ��ͳһ����
% ����ͨ�õ�U����h���� ���ó���
Uc_l = []; %�������ɶ������
Uc_c = []; %lamdaϵ������
Uc = [];
Uconstant_0 = [];
Uconstant_0 = blkdiag(1, Uconstant_0);%���ʼΪUconstant������ϵ��1 for ksi0 ������
Uconstant_0 = blkdiag(1, Uconstant_0);%���ʼΪUconstant������ϵ��1 for ksi_hat0 ������
Ulamda_0 = [];
Ulamda_0 = blkdiag(-1, Ulamda_0); %���ʼΪUlamda������ϵ��-1 for ksi0 ������
Ulamda_0 = blkdiag(-1, Ulamda_0); %���ʼΪUlamda������ϵ��-1 for ksi_hat0 ������
for t = 1:T
    Uconstant = []; %����ϵ��lamda���Ϊ1Լ����ϵ������
    for w = 1:W
        Uconstant = blkdiag(Uconstant,ones(1,vN));
    end
    Ulamda = blkdiag(-verts(:,1+(t-1)*2*vN:vN+(t-1)*2*vN),-verts(:,1+vN+(t-1)*2*vN:2*vN*t)); %����͹��ϱ�ʾksiԼ����ϵ������
    Uc_l = blkdiag(Ulamda_0,Uc_l); % U�����ϲ��֣���͹�����㹹��
    Uc_l = blkdiag(Uc_l,Ulamda); % U�����ϲ��֣���͹�����㹹��
    Uc_c = blkdiag(Uconstant_0,Uc_c); %U�����²��֣���1���ʵ�ֶ���ϵ�����Ϊ1
    Uc_c = blkdiag(Uc_c,Uconstant); %U�����²��֣���1���ʵ�ֶ���ϵ�����Ϊ1
    Uc = [Uc_l;Uc_c]; %͹����ʽԼ��U����
    Wc_l = diag(ones(t*W*(1+bN)+2*t,1)); %W�����ϲ��֣���λ��
    Wc_c = zeros(t*W+2*t,t*W*(1+bN)+2*t); %W�����²��֣�0����
    Wc = [Wc_l;Wc_c];
    hc = [zeros(t*W*(1+bN) + 2*t,1);ones(t*W + 2*t,1)]; %���쳣�������� = ������Z��������
    for n = 1:N %�������нڵ�
        % �����и��Ͻ�Լ��
        Lamda_lup = [sdpvar(t*W*(1+bN) + 2*t,1); sdpvar(t*W + 2*t,1)]; %�����ʽ��ż����lamda���� = h����ά��
        Lamda2_lup = sdpvar((t*W)*vN + 2*t,1); %���첻��ʽ��ż����lamda���� = vertsά��
        Zlup = -Zhat_nonb(Yl,t,T,W,n,Lup(n,1),bN);
        cons = [cons, Wc'* Lamda_lup == Zlup'];
        cons = [cons, Uc'* Lamda_lup + Lamda2_lup == 0];
        cons = [cons, hc'* Lamda_lup >= 0];
        cons = [cons, Lamda2_lup >= 0];
        % �����и��½�Լ��
        Lamda_llow = [sdpvar(t*W*(1+bN) + 2*t,1); sdpvar(t*W + 2*t,1)]; 
        Lamda2_llow = sdpvar((t*W)*vN + 2*t,1);
        Zllow = Zhat_nonb(Yl,t,T,W,n,Llow(n,1),bN);
        cons = [cons, Wc'* Lamda_llow == Zllow'];
        cons = [cons, Uc'* Lamda_llow + Lamda2_llow == 0];
        cons = [cons, hc'* Lamda_llow >= 0];
        cons = [cons, Lamda2_llow >= 0];
        %�ж��Ƿ��Ƿ�緢���ڵ㣬���Ϸ�緢��Լ��
        if ismember(n,Wbus)
            index = find(Wbus==n);
            Lamda_w = [sdpvar(t*W*(1+bN) + 2*t,1); sdpvar(t*W + 2*t,1)]; 
            Lamda2_w = sdpvar((t*W)*vN + 2*t,1);
            Aw = [PW_miu((t-1)*W+index,1)-YPw(index,t), -YPw(index,T+1+Sumt(t-1)*W*bN:T+Sumt(t)*W*bN)];
            Zw = [];
            for tt = 1:t
                if tt == t
                    Zw = [Zw,0,Aw(1,1)];
                else
                    Zw = [Zw,0,0];
                end
            end
            for tt = 1:t
                for w = 1:W
                    if (tt==t && w==index)
                        Zw = [Zw,1,Aw(1,2+(tt-1)*W*bN+(w-1)*bN:1+(tt-1)*W*bN+w*bN)];
                    else
                        Zw = [Zw,0,Aw(1,2+(tt-1)*W*bN+(w-1)*bN:1+(tt-1)*W*bN+w*bN)];
                    end
                end
            end
            cons = [cons, Wc'* Lamda_w == Zw'];
            cons = [cons, Uc'* Lamda_w + Lamda2_w == 0];
            cons = [cons, hc'* Lamda_w >= 0];
            cons = [cons, Lamda2_w >= 0];
            %�������½�
            Lamda_wlow = [sdpvar(t*W*(1+bN) + 2*t,1); sdpvar(t*W + 2*t,1)]; %�����ʽ��ż����lamda���� = h����ά��
            Lamda2_wlow = sdpvar((t*W)*vN + 2*t,1); %���첻��ʽ��ż����lamda���� = vertsά��
            Zwlow = Zhat_nonb(YPw,t,T,W,index,0,bN);
            cons = [cons, Wc'* Lamda_wlow == Zwlow'];
            cons = [cons, Uc'* Lamda_wlow + Lamda2_wlow == 0];
            cons = [cons, hc'* Lamda_wlow >= 0];
            cons = [cons, Lamda2_wlow >= 0];
        end
        %�ж��Ƿ��ǻ�������ڵ㣬�ǵĻ����������Լ��
        if ismember(n,Gbus) 
            index = find(Gbus==n);
            %��ͷ������Լ��
            Lamda_wan = [sdpvar(t*W*(1+bN) + 2*t,1); sdpvar(t*W + 2*t,1)]; 
            Lamda2_wan = sdpvar((t*W)*vN + 2*t,1);
            Zwan = Zhat_nonb(YS,t,T,W,index,0,bN);
            cons = [cons, Wc'* Lamda_wan == Zwan'];
            cons = [cons, Uc'* Lamda_wan + Lamda2_wan == 0];
            cons = [cons, hc'* Lamda_wan >= 0];
            cons = [cons, Lamda2_wan >= 0];
            
            % ����������Ի�
            for l = 0:(L-1)
                Lamda_cost = [sdpvar(t*W*(1+bN) + 2*t,1); sdpvar(t*W + 2*t,1)]; 
                Lamda2_cost = sdpvar((t*W)*vN + 2*t,1);
                p_i_l = Plow(index) + (Pup(index) - Plow(index)) / L * l;
                Acost = [Yz(index,t), Yz(index,T+1+Sumt(t-1)*W*bN:T+Sumt(t)*W*bN)] - (2*fc(index)*p_i_l+fb(index)) * [YG(index,t),YG(index,T+1+Sumt(t-1)*W*bN:T+Sumt(t)*W*bN)];
                Bcost = -(fa(index)-fc(index)*p_i_l*p_i_l) * Xu(index,t);
                Zcost = [];
                for tt = 1:t
                    if tt == t
                        Zcost = [Zcost,0,Acost(1,1) + Bcost];
                    else
                        Zcost = [Zcost,0,0];
                    end
                end
                for tt = 1:t 
                    for w = 1:W
                        Zcost = [Zcost,0,Acost(1,2+(tt-1)*W*bN+(w-1)*bN:1+(tt-1)*W*bN+w*bN)];
                    end
                end
                cons = [cons, Wc'* Lamda_cost == Zcost'];
                cons = [cons, Uc'* Lamda_cost + Lamda2_cost == 0];
                cons = [cons, hc'* Lamda_cost >= 0];
                cons = [cons, Lamda2_cost >= 0];
            end
            
            % ��������Լ��
            if (t-tao0(index)+1<=0)&&(max(0,-T0(index))<abs(t-tao0(index)+1))
                fit = 1;
            else
                fit = 0;
            end
            tao_it = max(1,t-Toff(index)-Tcold(index));
            Lamda_open = [sdpvar(t*W*(1+bN) + 2*t,1); sdpvar(t*W + 2*t,1)]; 
            Lamda2_open = sdpvar((t*W)*vN + 2*t,1);
            Ccost = Chot(index) - Ccold(index); %������ù���ϵ��
            Aopen = [YS(index,t)-fit*Ccost,YS(index,T+1+Sumt(t-1)*W*bN:T+Sumt(t)*W*bN)];
            Bopen = 0;
            for y = tao_it : t-1 % ����ػ�״̬dit�ľ��߱���
                Bopen = Bopen - Xd(index,y);
            end
            Bopen = Bopen + Xs(index,t); %���Ͽ���״̬sit�ľ��߱���
            Bopen = Ccost*Bopen;
            Zopen = [];
            for tt = 1:t
                if tt == t
                    Zopen = [Zopen,0,Aopen(1,1) + Bopen];
                else
                    Zopen = [Zopen,0,0];
                end
            end
            for tt = 1:t
                for w = 1:W
                    Zopen = [Zopen,0,Aopen(1,2+(tt-1)*W*bN+(w-1)*bN:1+(tt-1)*W*bN+w*bN)];
                end
            end
            cons = [cons, Wc'* Lamda_open == Zopen'];
            cons = [cons, Uc'* Lamda_open + Lamda2_open == 0];
            cons = [cons, hc'* Lamda_open >= 0];
            cons = [cons, Lamda2_open >= 0]; %����ʽconstraints������Լ������ʽ����Լ��
            
            %�����Ͻ�
            Lamda_up = [sdpvar(t*W*(1+bN) + 2*t,1); sdpvar(t*W + 2*t,1)];
            Lamda2_up = sdpvar((t*W)*vN + 2*t,1);
            Aup = [YG(index,t),YG(index,T+1+Sumt(t-1)*W*bN:T+Sumt(t)*W*bN)]; 
            Bup = Pup(index) * Xu(index,t); 
            Zup = [];
            for tt = 1:t
                if tt == t
                    Zup = [Zup,0,Bup - Aup(1,1)];
                else
                    Zup = [Zup,0,0];
                end
            end
            for tt = 1:t %����ǰʱ���õ���ǰt��ʱ��W������ȡ����Ӧϵ��
                for w = 1:W
                    Zup = [Zup,0,-Aup(1,2+(tt-1)*W*bN+(w-1)*bN:1+(tt-1)*W*bN+w*bN)];
                end
            end
            cons = [cons, Wc'* Lamda_up == Zup'];
            cons = [cons, Uc'* Lamda_up + Lamda2_up == 0];
            cons = [cons, hc'* Lamda_up >= 0];
            cons = [cons, Lamda2_up >= 0]; 
            
            %�����½�
            Lamda_low = [sdpvar(t*W*(1+bN) + 2*t,1); sdpvar(t*W + 2*t,1)];
            Lamda2_low = sdpvar((t*W)*vN + 2*t,1);
            Alow = [YG(index,t),YG(index,T+1+Sumt(t-1)*W*bN:T+Sumt(t)*W*bN)];
            Blow = Plow(index) * Xu(index,t);
            Zlow = [];
            for tt = 1:t
                if tt == t
                    Zlow = [Zlow,0,Alow(1,1) - Blow];
                else
                    Zlow = [Zlow,0,0];
                end
            end
            for tt = 1:t 
                for w = 1:W
                    Zlow = [Zlow,0,Alow(1,2+(tt-1)*W*bN+(w-1)*bN:1+(tt-1)*W*bN+w*bN)];
                end
            end
            cons = [cons, Wc'* Lamda_low == Zlow'];
            cons = [cons, Uc'* Lamda_low + Lamda2_low == 0];
            cons = [cons, hc'* Lamda_low >= 0];
            cons = [cons, Lamda2_low >= 0];
            
            %������
            Lamda_ramp_up = [sdpvar(t*W*(1+bN) + 2*t,1); sdpvar(t*W + 2*t,1)];
            Lamda2_ramp_up = sdpvar((t*W)*vN + 2*t,1);
            if t == 1
                Aramp_up =  -[YG(index,t),YG(index,T+1:T+W*bN)]; %��t=1ʱ��ֻʣs��p1����
                Bramp_up = Pstart(index) * Xs(index,t);
            else
                Aramp_up = [YG(index,t-1),YG(index,T+1+Sumt(t-2)*W*bN:T+Sumt(t-1)*W*bN),zeros(1,W*bN)] - [YG(index,t),YG(index,T+1+Sumt(t-1)*W*bN:T+Sumt(t)*W*bN)]; 
                Bramp_up = Pramp(index) * Xu(index,t-1) + Pstart(index) * Xs(index,t); 
            end
            Zramp_up = [];
            for tt = 1:t
                if tt == t
                    Zramp_up = [Zramp_up,0,Aramp_up(1,1) + Bramp_up];
                else
                    Zramp_up = [Zramp_up,0,0];
                end
            end
            for tt = 1:t 
                for w = 1:W
                    Zramp_up = [Zramp_up,0,Aramp_up(1,2+(tt-1)*W*bN+(w-1)*bN:1+(tt-1)*W*bN+w*bN)];
                end
            end
            cons = [cons, Wc'* Lamda_ramp_up == Zramp_up'];
            cons = [cons, Uc'* Lamda_ramp_up + Lamda2_ramp_up == 0];
            cons = [cons, hc'* Lamda_ramp_up >= 0];
            cons = [cons, Lamda2_ramp_up >= 0];
            
            %������
            Lamda_ramp_down = [sdpvar(t*W*(1+bN) + 2*t,1); sdpvar(t*W + 2*t,1)];
            Lamda2_ramp_down = sdpvar((t*W)*vN + 2*t,1);
            if t == 1
                Aramp_down = [YG(index,t),YG(index,T+1:T+W*bN)]; %��t=1ʱ��ʣ��d,u��p1����
                Bramp_down = Pshut(index) * Xd(index,t) + Pramp(index) * Xu(index,t);
            else
                Aramp_down = [YG(index,t),YG(index,T+1+Sumt(t-1)*W*bN:T+Sumt(t)*W*bN)] - [YG(index,t-1),YG(index,T+1+Sumt(t-2)*W*bN:T+Sumt(t-1)*W*bN), zeros(1,W*bN)]; %������������ksi_hatǰϵ�� Pt - Pt-1
                Bramp_down = Pshut(index) * Xd(index,t) + Pramp(index) * Xu(index,t); %��������ksi_tineǰϵ��
            end
            Zramp_down = [];
            for tt = 1:t
                if tt == t
                    Zramp_down = [Zramp_down,0,Aramp_down(1,1) + Bramp_down];
                else
                    Zramp_down = [Zramp_down,0,0];
                end
            end
            for tt = 1:t 
                for w = 1:W
                    Zramp_down = [Zramp_down,0,Aramp_down(1,2+(tt-1)*W*bN+(w-1)*bN:1+(tt-1)*W*bN+w*bN)];
                end
            end
            cons = [cons, Wc'* Lamda_ramp_down == Zramp_down'];
            cons = [cons, Uc'* Lamda_ramp_down + Lamda2_ramp_down== 0];
            cons = [cons, hc'* Lamda_ramp_down >= 0];
            cons = [cons, Lamda2_ramp_down >= 0];
          
            %��������
            %����������U0��Ϊ0������������û�ж�t������ػ�����ʱ�������ж�
            %�����;��߱���ʱ����Լ������ֱ��д
            omiga = max(0,t-Ton(index))+1;
            if (omiga<=t)
                Bon_s = 0;
                for o = omiga:t
                    Bon_s = Bon_s + Xs(index,o);
                end
                Bon_u = Xu(index,t);
                cons = [cons, Bon_s <= Bon_u];
            end
            %�ػ�����
            omiga = max(0,t-Toff(index))+1;
            if (t >= 1+L0(index)&&(omiga<=t)) % �ȼ���(t >= 1+L0(g))&&(t <= T)����Ϊѭ����tһ��С�ڵ���T���Ժ�벿�����Ʋ�Ҫ�ˡ�
                Boff_d = 0;
                for o = omiga:t
                    Boff_d = Boff_d - Xd(index,o);
                end
                Boff_u = Xu(index,t);
                cons = [cons, Boff_d <= 1-Boff_u]; 
            end
        end
%         % ��·����Լ��
        for i = 1:size(all_branch.I,1) %�ӵ�һ��֧·��ʼѭ����������֧·
            left = all_branch.I(i); %֧·�����յ㼴�ɵõ�B����
            right = all_branch.J(i);
            abs_x4branch = abs(1/B(left,right));  % ��ǰ֧·���迹�ľ���ֵ |x_ij|
            % ����ʽ�Ҷ���
            Lamda_Fup = [sdpvar(t*W*(1+bN) + 2*t,1); sdpvar(t*W + 2*t,1)];
            Lamda2_Fup = sdpvar((t*W)*vN + 2*t,1);
            AFup = [Ytheta(right,t) - Ytheta(left,t) + abs_x4branch*all_branch.P(i),Ytheta(right,T+1+Sumt(t-1)*W*bN:T+Sumt(t)*W*bN) - Ytheta(left,T+1+Sumt(t-1)*W*bN:T+Sumt(t)*W*bN)]; % theta_j - theta_i + F
            ZFup = [];
            for tt = 1:t
                if tt == t
                    ZFup = [ZFup,0,AFup(1,1)];
                else
                    ZFup = [ZFup,0,0];
                end
            end
            for tt = 1:t
                for w = 1:W
                    ZFup = [ZFup,0,AFup(1,2+(tt-1)*W*bN+(w-1)*bN:1+(tt-1)*W*bN+w*bN)];
                end
            end
            cons = [cons, Wc'* Lamda_Fup == ZFup'];
            cons = [cons, Uc'* Lamda_Fup + Lamda2_Fup == 0];
            cons = [cons, hc'* Lamda_Fup >= 0];
            cons = [cons, Lamda2_Fup >= 0];
            % ����ʽ�����
            Lamda_Flow = [sdpvar(t*W*(1+bN) + 2*t,1); sdpvar(t*W + 2*t,1)];
            Lamda2_Flow = sdpvar((t*W)*vN + 2*t,1);
            AFlow = [Ytheta(left,t) - Ytheta(right,t) + abs_x4branch*all_branch.P(i),Ytheta(left,T+1+Sumt(t-1)*W*bN:T+Sumt(t)*W*bN) - Ytheta(right,T+1+Sumt(t-1)*W*bN:T+Sumt(t)*W*bN)]; % theta_i - theta_j + F
            ZFlow = [];
            for tt = 1:t
                if tt == t
                    ZFlow = [ZFlow,0,AFlow(1,1)];
                else
                    ZFlow = [ZFlow,0,0];
                end
            end
            for tt = 1:t
                for w = 1:W
                    ZFlow = [ZFlow,0,AFlow(1,2+(tt-1)*W*bN+(w-1)*bN:1+(tt-1)*W*bN+w*bN)];
                end
            end
            cons = [cons, Wc'* Lamda_Flow == ZFlow'];
            cons = [cons, Uc'* Lamda_Flow + Lamda2_Flow == 0];
            cons = [cons, hc'* Lamda_Flow >= 0];
            cons = [cons, Lamda2_Flow >= 0];
        end
    end
end
% end of ����ʽԼ��ͳһ����

% ��ʽԼ��
% ���ػ�״̬��ʽԼ��
for g = 1:G
    for t = 1:T
        if t == 1
            cons = [cons, Xs(g,t) - Xd(g,t) == Xu(g,t) - u0(g,1)]; 
        else
            cons = [cons, Xs(g,t) - Xd(g,t) == Xu(g,t) - Xu(g,t-1)]; %��ʽ���޳�������Z0���迼��
        end
    end
end
% end of ���ػ�״̬��ʽԼ��

% ֱ������Լ����ʽ��ʽ
for n = 1:N %�������нڵ�
    for t = 1:T
        Zac = zeros(1,1+t*W*bN); %�����ͱ������߹���
        dac = 0; %������
        Zac = Zac + [Yl(n,t),Yl(n,T+1+Sumt(t-1)*W*bN:T+Sumt(t)*W*bN)];
        if ismember(n,Gbus) %�ж��Ƿ��ǻ�������ڵ�
            index = find(Gbus==n);
            Zac = Zac + [YG(index,t),YG(index,T+1+Sumt(t-1)*W*bN:T+Sumt(t)*W*bN)];
        end
        if ismember(n,Wbus) %�ж��Ƿ��Ƿ�����ڵ�
            index = find(Wbus==n);
            Zac = Zac + [YPw(index,t),YPw(index,T+1+Sumt(t-1)*W*bN:T+Sumt(t)*W*bN)];
        end
        for j = 1:N %���Ͻڵ㳱��
            if B(n,j) ~=0
                Zac = Zac - B(n,j) * [Ytheta(j,t),Ytheta(j,T+1+Sumt(t-1)*W*bN:T+Sumt(t)*W*bN)]; 
            end
        end
        if ismember(n,Dbus) %�ж��Ƿ��Ǹ��ؽڵ�
            index = find(Dbus==n);
            dac = dac + SCUC_data.busLoad.node_P(t,index);
        end
        cons = [cons, Zac(1,1) == dac]; 
        cons = [cons, Zac(2:t*W*bN)' == 0]; 
    end
end
% end of ֱ������Լ����ʽ��ʽ
% end of ��ʽԼ��

% ����Ŀ�꺯��Լ��
Cobj = zeros(1,T*W); %ksiϵ������
Aobj = zeros(1,T*W*bN); %ksi_hatϵ������
Cobj0 = zeros(1,T); %ksi0ϵ������
Aobj0 = zeros(1,T); %ksi_hat0ϵ������
Bobj0 = 0; %ksi_tine0ϵ������
Uobj_l = []; %Ŀ�꺯��͹��Լ����ʽԼ���������
Uobj_c = []; %Ŀ�꺯��͹��Լ����ʽԼ��lamda���Ϊ1ϵ������
for t = 1:T
    for n = 1:N
        Aobj0 = Aobj0+ 100*[zeros(1,t-1),Yl(n,t),zeros(1,T-t)];
        Aobj = Aobj + 100*[Yl(n,T+1+Sumt(t-1)*W*bN:T+Sumt(t)*W*bN),zeros(1,(T-t)*W*bN)]; 
        if ismember(n,Gbus) %�ж��Ƿ��ǻ�������ڵ�
            index = find(Gbus==n);
            Aobj0 = Aobj0+ [zeros(1,t-1),Yz(index,t),zeros(1,T-t)] + [zeros(1,t-1),YS(index,t),zeros(1,T-t)];
            Bobj0 = Bobj0 + Chot(index)*Xs(index,t);
            Aobj = Aobj + [Yz(index,T+1+Sumt(t-1)*W*bN:T+Sumt(t)*W*bN) + YS(index,T+1+Sumt(t-1)*W*bN:T+Sumt(t)*W*bN), zeros(1,(T-t)*W*bN)]; %������zit��Sit����ϵ����Ӧ������
        end
    end 
    Ulamda = blkdiag(verts(:,1+(t-1)*2*vN:vN+(t-1)*2*vN),verts(:,1+vN+(t-1)*2*vN:2*vN*t)); %����͹��ϱ�ʾksiԼ����ϵ������
    Uconstant = []; %����ϵ��lamda���Ϊ1Լ����ϵ������
    for w = 1:W
        Uconstant = blkdiag(Uconstant,ones(1,vN));
    end
    Uobj_l = blkdiag(Ulamda_0,Uobj_l);
    Uobj_l = blkdiag(Uobj_l,-Ulamda);
    Uobj_c = blkdiag(Uconstant_0,Uobj_c);
    Uobj_c = blkdiag(Uobj_c,Uconstant);
end

U = [Uobj_l;Uobj_c];
W_l = diag(ones(T*W*kl+2*t,1));
W_c = zeros(T*W+2*t,T*W*kl+2*t);
W_obj = [W_l;W_c];
Zobj = [];
Zobj_0 = [];
for t = 1:T
    if t == 1
        Zobj_0 = [Zobj_0,0,Aobj0(1,t)+Bobj0];
    else
        Zobj_0 = [Zobj_0,0,Aobj0(1,t)];
    end
    for w = 1:W
        Zobj = [Zobj,0,Aobj(1,1+(t-1)*2*bN+(w-1)*bN:(t-1)*2*bN+w*bN)];
    end
end
Zobj = [Zobj_0,Zobj]; %ksi0,ksi_hat0,ksi_tine0,ksi,ksi_hat,ksi_tine
hobj = [zeros(1,T*W*kl+2*t),ones(1,T*W+2*t)]'; %͹��������
v = sdpvar(1,M); %�����һ��lagrangian��ʽԼ������v
beta = sdpvar(1); %�����һ��lagrangian����ʽԼ������beta
y1 = sdpvar((T*W*(kl+1))+2*2*t,M);%����ڶ��ε�ʽlagrangian����y1����hͬά��ÿ����������һ�������ĳ�������
constraints = [];
constraints = [constraints, beta >= 0]; %����ʽ����Ҫ���ڵ���0
for m = 1:M %��ʼ����Ŀ�꺯��ת��������Լ��
    y_j = y1(:,m); 
    mid_obj = Zobj' - W_obj'*y_j;
    constraints = [constraints, (mid_obj' * ksi_wan{m} + hobj' * y_j) <= M*v(1,m)];
    constraints = [constraints, abs(mid_obj) <= beta];
    constraints = [constraints, U' * y_j >= 0];
end
% end of ����Ŀ�꺯��Լ��

constraints = [constraints, cons]; %�������Լ��

objective = sum(v) + eps*beta; %����Ŀ�꺯��

% options = sdpsettings('verbose',2,'debug',1,'savesolveroutput',1,'savesolverinput',1);
% options = sdpsettings('verbose',2,'solver','mosek','debug',1,'savesolveroutput',1,'savesolverinput',1);
% options.mosek.MSK_DPAR_OPTIMIZER_MAX_TIME = 1000;
options = sdpsettings('verbose',2,'solver','mosek','debug',1,'savesolveroutput',1,'savesolverinput',1);
options.mip.tolerances.mipgap=0.003;
% options.cplex.timelimit = 1000;
sol = optimize(constraints,objective,options);

% Analyze error flags
if sol.problem == 0
    % Extract and display value
    Obj = value(objective);
    disp(Obj);

    real_PG = zeros(G,T); %ʵ�ʻ���������
    real_z = zeros(G,T); %ʵ�ʻ����������
    real_S = zeros(G,T); %ʵ�ʻ������鿪������
    real_l = zeros(N,T); %ʵ�ʸ����и���
    real_PW = zeros(W,T); %ʵ�ʷ���������
    real_theta = zeros(N,T); %ʵ�ʽڵ����
   
    ksi_hat = ksi_wan2{18}(1:T*W*bN);
    for g = 1:G
        for t = 1:T
            real_PG(g,t) = YG(g,t) + sum(value(YG(g,T+1+Sumt(t-1)*W*bN:T+Sumt(t)*W*bN))' .* ksi_hat(1:t*W*bN));
            real_z(g,t) = Yz(g,t) + sum(value(Yz(g,T+1+Sumt(t-1)*W*bN:T+Sumt(t)*W*bN))' .* ksi_hat(1:t*W*bN));
            real_S(g,t) = YS(g,t) + sum(value(YS(g,T+1+Sumt(t-1)*W*bN:T+Sumt(t)*W*bN))' .* ksi_hat(1:t*W*bN));
        end
    end
    
    for w = 1:W
        for t = 1:T
            real_PW(w,t) = YPw(w,t) + sum(value(YPw(w,T+1+Sumt(t-1)*W*bN:T+Sumt(t)*W*bN))' .* ksi_hat(1:t*W*bN));
        end
    end

    for n = 1:N
        for t = 1:T
            real_theta(n,t) = Ytheta(n,t) + sum(value(Ytheta(n,T+1+Sumt(t-1)*W*bN:T+Sumt(t)*W*bN))' .* ksi_hat(1:t*W*bN));
            real_l(n,t) = Yl(n,t) + sum(value(Yl(n,T+1+Sumt(t-1)*W*bN:T+Sumt(t)*W*bN))' .* ksi_hat(1:t*W*bN));
        end
    end
    
    disp(sol.solvertime);
else
    disp('Oh shit!, something was wrong!');
    sol.info
    yalmiperror(sol.problem)
end