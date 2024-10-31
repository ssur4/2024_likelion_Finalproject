export NAME="team3cluster.lion.nyhhs.com"
export REGION="ap-northeast-2"
export KOPS_STATE_STORE="s3://team3cluster.lion2.nyhhs.com"
export MASTER_SIZE="t3.xlarge"
export NODE_SIZE="t3.xlarge"
export ZONES="ap-northeast-2a,ap-northeast-2b"  #ALB 사용을 위해 가용영역2개설정
export CONTROL_PLANE_ZONES="ap-northeast-2a"  # 컨트롤 플레인은 단일 가용영역
export cln="team3cluster.lion.nyhhs.com"


kops create cluster team3cluster.lion.nyhhs.com \
--node-count 1 \
--zones $ZONES \
--node-size $NODE_SIZE \
--control-plane-size $MASTER_SIZE \
--control-plane-zones $CONTROL_PLANE_ZONES \
--control-plane-volume-size 40 \
--node-volume-size 40 \
--networking calico \
--topology private \
--ssh-public-key ~/.ssh/id_rsa.pub
