export NAME="team3cluster"
export REGION="ap-northeast-2"
export KOPS_STATE_STORE="s3://team3cluster.lion2.nyhhs.com"
export MASTER_SIZE="t3.xlarge"
export NODE_SIZE="t3.xlarge"
export ZONES="ap-northeast-2a"
export cln="team3cluster.lion.nyhhs.com"

# HA
# export ZONES="ap-northeast-2a,ap-northeast-2b"

# ADD
# export VPC_ID=vpc-0a9f23a7a4756f5b2
#export NETWORK_CIDR=10.1.0.0/16
#export SUBNET_ID=subnet-0d820a84df7f80b13
#export SUBNET_CIDR=10.1.1.0/24

# --network-id $VPC_ID \
# --network-cidr $NETWORK_CIDR \
# --subnets= $SUBNET_ID \


kops create cluster team3cluster.lion.nyhhs.com \
--node-count 1 \
--zones $ZONES \
--node-size $NODE_SIZE \
--control-plane-size $MASTER_SIZE \
--control-plane-zones $ZONES \
--control-plane-volume-size 40 \
--node-volume-size 40 \
--networking calico \
--topology private \
--ssh-public-key ~/.ssh/id_rsa.pub
