%%%   ylf��д��2017.12.7
%%%   ��ڵ㵼�ɾ���
function Y = SCUC_nodeY(SCUC_data, type) 

Y.type = type;  % type = 'DC'Ϊֱ������   type = 'AC'Ϊ����������Y
if strcmp(type, 'DC') == 1
    SCUC_data.branch.R = 0;
    SCUC_data.branchTransformer.R = 0;
end


n = SCUC_data.baseparameters.busN;  %%%  

%%%   �γ�֧·���ɾ���
Y1        = sparse(1./(SCUC_data.branch.R + 1i * SCUC_data.branch.X));
Y11       = sparse(SCUC_data.branch.I,SCUC_data.branch.J,Y1,n,n);
branchYij = sparse(-Y11-Y11.');                     %%%  ֧·���ɵķǶԽ�Ԫ��

Ya        = sparse(SCUC_data.branch.I,SCUC_data.branch.J,1i*SCUC_data.branch.B,n,n);
Yc        = sparse(Ya+Ya.');
branchYii = sparse(diag(sum(-branchYij)+sum(Yc)));  %%%  �γ�֧·���ɾ���Խ�Ԫ��
branchY   = sparse(branchYij+branchYii);            %%%  �γ�֧·����


%%%   ��ѹ��֧·����
Y2                 = sparse(1./(SCUC_data.branchTransformer.R+1i*SCUC_data.branchTransformer.X));
transformerYij     = sparse(SCUC_data.branchTransformer.I,SCUC_data.branchTransformer.J,-SCUC_data.branchTransformer.K.*Y2,n,n);
transformerYij     = transformerYij+transformerYij.';                                                %%%  ��ѹ�����ɷǶԽ�Ԫ��
transformerYii     = sparse(SCUC_data.branchTransformer.I,SCUC_data.branchTransformer.I,(SCUC_data.branchTransformer.K.^2).*Y2,n,n);  %%%  ��ѹ�����ɶ�Ӧi�Խ�Ԫ��
transformerYjj     = sparse(SCUC_data.branchTransformer.J,SCUC_data.branchTransformer.J,Y2,n,n);                           %%%  ��ѹ�����ɶ�ӦJ�Խ�Ԫ��
branchTransformerY = sparse(transformerYii+transformerYjj+transformerYij);                           %%%  ��ѹ��֧·����

%%%   �γɽڵ㵼�ɾ���
YY = sparse(branchY+branchTransformerY);  %%%  ֧·���ɣ���ѹ������
Y.G = sparse(real(YY));
Y.B = sparse(imag(YY));