export NAME="team3cluster"
export REGION="ap-northeast-2"
export KOPS_STATE_STORE="s3://team3cluster.lion2.nyhhs.com"
export MASTER_SIZE="t3.xlarge"
export NODE_SIZE="t3.xlarge"
export ZONES="ap-northeast-2a"
# export ZONES="ap-northeast-2a,ap-northeast-2b"
export cln="team3cluster.lion.nyhhs.com"
export VPC_ID="vpc-0a9f23a7a4756f5b2"
export NETWORK_CIDR="10.1.0.0/16"


kops create cluster team3cluster.lion.nyhhs.com \
--node-count 1 \
--zones $ZONES \
--node-size $NODE_SIZE \
--control-plane-size $MASTER_SIZE \
--control-plane-zones $ZONES \
--control-plane-volume-size 40 \
--node-volume-size 40 \
--networking calico \
--network-id $VPC_ID \
--network-cidr $NETWORK_CIDR \
--topology public \
--ssh-public-key ~/.ssh/id_rsa.pub
