# kops 활용 k8s cluster 구축#2
---
## 기존 VPC에서 실행
- `--network-id` 인수를 사용한다.
```shell
# VPC 관련 환경변수 설정
export KOPS_STATE_STORE=s3://<somes3bucket>
export CLUSTER_NAME=<sharedvpc.mydomain.com>
export VPC_ID=vpc-12345678 # replace with your VPC id
export NETWORK_CIDR=10.100.0.0/16 # replace with the cidr for the VPC ${VPC_ID}

# 클러스터 설정 생성
kops create cluster --zones=us-east-1b --name=${CLUSTER_NAME} --network-id=${VPC_ID}
```

- 클러스터 설정 확인
	- 설정에서 `networkCIDR, networkID` 를 `기존 VPC ID, CIDR` 와 일치시킨다.
	- 이후, `kops update cluster` 를 통해서 미리 본다.
	- 이상이 없으면 `--yes` 를 통해서 생성한다.
```shell
kops edit cluster ${CLUSTER_NAME}
---
metadata:
  name: ${CLUSTER_NAME}
spec:
  cloudProvider: aws
  networkCIDR: ${NETWORK_CIDR}
  networkID: ${VPC_ID}
  nonMasqueradeCIDR: 100.64.0.0/10
  subnets:
  - cidr: 172.20.32.0/19
    name: us-east-1b
    type: Public
    zone: us-east-1b
.
.
.
---
```
## 기존 VPC에서 클러스터를 생성하기 위한 고급 옵션
- kops의 `--topology public/private` 둘 모두, 퍼블릭 서브넷에 클러스터를 생성할 수 있다.
- 서브넷 지정 인수 `--subnets` 를 사용한다.
- `--subents` 을 통해서 서브넷을 지정할 때, `--network-id` 는 선택사항이다.
```shell
export KOPS_STATE_STORE=s3://<somes3bucket>
export CLUSTER_NAME=<sharedvpc.mydomain.com>
export VPC_ID=vpc-12345678 # replace with your VPC id
export NETWORK_CIDR=10.100.0.0/16 # replace with the cidr for the VPC ${VPC_ID}
export SUBNET_ID=subnet-12345678 # replace with your subnet id
export SUBNET_CIDR=10.100.0.0/24 # replace with your subnet CIDR
export SUBNET_IDS=$SUBNET_IDS # replace with your comma separated subnet ids

# 클러스터 설정 생성
kops create cluster --zones=us-east-1b --name=${CLUSTER_NAME} --subnets=${SUBNET_IDS}
```

- 클러스터 설정 확인
```shell
kops edit cluster ${CLUSTER_NAME}
---
metadata:
  name: ${CLUSTER_NAME}
spec:
  cloudProvider: aws
  networkCIDR: ${NETWORK_CIDR}
  networkID: ${VPC_ID}
  nonMasqueradeCIDR: 100.64.0.0/10
  subnets:
  - cidr: ${SUBNET_CIDR}
    id: ${SUBNET_ID}
    name: us-east-1b
    type: Public
    zone: us-east-1b
.
.
.
---

# 클러스터 실제 생성
kops update cluster ${CLUSTER_NAME} --yes
```

---
# 1. topology 만 변경하여 클러스터 생성
- `--topology` 만 private 로 변경하여 클러스터 생성
```shell
[root@~] vi setup-ha-k8s-private.sh 
---
export NAME="team3cluster"
export REGION="ap-northeast-2"
export KOPS_STATE_STORE="s3://team3cluster.lion2.nyhhs.com"
export MASTER_SIZE="t3.xlarge"
export NODE_SIZE="t3.xlarge"
export ZONES="ap-northeast-2a"
export cln="team3cluster.lion.nyhhs.com"

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
---

# 스크립트 적용 -> 클러스터 설정 생성
[root@~] . setup-ha-k8s-private.sh
Cluster configuration has been created.
```
- 클러스터 설정 확인
```shell
[root@~] kops edit cluster --name team3cluster.lion.nyhhs.com
---
apiVersion: kops.k8s.io/v1alpha2
kind: Cluster
metadata:
  creationTimestamp: "2024-10-11T02:29:28Z"
  name: team3cluster.lion.nyhhs.com
spec:
  api:
    loadBalancer:
      class: Network
      type: Public
  authorization:
    rbac: {}
  channel: stable
  cloudProvider: aws
  configBase: s3://team3cluster.lion2.nyhhs.com/team3cluster.lion.nyhhs.com
  etcdClusters:
  - cpuRequest: 200m
    etcdMembers:
    - encryptedVolume: true
      instanceGroup: control-plane-ap-northeast-2a
      name: a
    manager:
      backupRetentionDays: 90
    memoryRequest: 100Mi
    name: main
  - cpuRequest: 100m
    etcdMembers:
    - encryptedVolume: true
      instanceGroup: control-plane-ap-northeast-2a
      name: a
    manager:
      backupRetentionDays: 90
    memoryRequest: 100Mi
    name: events
  iam:
    allowContainerRegistry: true
    legacy: false
  kubelet:
    anonymousAuth: false
  kubernetesApiAccess:
  - 0.0.0.0/0
  - ::/0
  kubernetesVersion: 1.30.2
  networkCIDR: 172.20.0.0/16
  networking:
    calico: {}
  nonMasqueradeCIDR: 100.64.0.0/10
  sshAccess:
  - 0.0.0.0/0
  - ::/0
  subnets:
  - cidr: 172.20.128.0/17
    name: ap-northeast-2a
    type: Private ############################################
    zone: ap-northeast-2a
  - cidr: 172.20.0.0/20
    name: utility-ap-northeast-2a
    type: Utility
    zone: ap-northeast-2a
  topology:
    dns:
      type: None
```
- 서브넷이 `private` 로 생성된 것을 확인할 수 있다.

# 2. topology private & 기존 VPC 및 서브넷을 지정하여 생성
```sh
vi setup-ha-k8s-vpc-subnet-private.sh
---
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
export VPC_ID=vpc-0a9f23a7a4756f5b2
export NETWORK_CIDR=10.1.0.0/16
export SUBNET_ID=subnet-0d820a84df7f80b13
export SUBNET_CIDR=10.1.1.0/24


kops create cluster team3cluster.lion.nyhhs.com \
--node-count 1 \
--zones $ZONES \
--node-size $NODE_SIZE \
--control-plane-size $MASTER_SIZE \
--control-plane-zones $ZONES \
--control-plane-volume-size 40 \
--node-volume-size 40 \
--network-id $VPC_ID \
--network-cidr $NETWORK_CIDR
--subnets $SUBNET_ID \
--networking calico \
--topology private \
--ssh-public-key ~/.ssh/id_rsa.pub
---

# 클러스터 설정 실행
source setup-ha-k8s-vpc-subnet-private.sh
```
- 클러스터 설정 확인
	- kubeproxy 도 사용 불가로 설정되어있다.
	- 서브넷도 퍼블릭으로 되어있다..

# 3. private 로 생성 후, CIDR 변경
```sh
[root@~] vi setup-ha-k8s-private.sh 
---
export NAME="team3cluster"
export REGION="ap-northeast-2"
export KOPS_STATE_STORE="s3://team3cluster.lion2.nyhhs.com"
export MASTER_SIZE="t3.xlarge"
export NODE_SIZE="t3.xlarge"
export ZONES="ap-northeast-2a"
export cln="team3cluster.lion.nyhhs.com"

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
--------------------------------

[root@~] source setup-ha-k8s-private.sh
```

# 4. 클러스터 설정 수동 변경 및 생성
```sh
[root@~] kops edit cluster team3cluster.lion.nyhhs.com
---
apiVersion: kops.k8s.io/v1alpha2
kind: Cluster
metadata:
  creationTimestamp: "2024-10-11T04:40:03Z"
  name: team3cluster.lion.nyhhs.com
spec:
  api:
    loadBalancer:
      class: Network
      type: Public
  authorization:
    rbac: {}
  channel: stable
  cloudProvider: aws
  configBase: s3://team3cluster.lion2.nyhhs.com/team3cluster.lion.nyhhs.com
  etcdClusters:
  - cpuRequest: 200m
    etcdMembers:
    - encryptedVolume: true
      instanceGroup: control-plane-ap-northeast-2a
      name: a
    manager:
      backupRetentionDays: 90
    memoryRequest: 100Mi
    name: main
  - cpuRequest: 100m
    etcdMembers:
    - encryptedVolume: true
      instanceGroup: control-plane-ap-northeast-2a
      name: a
    manager:
      backupRetentionDays: 90
    memoryRequest: 100Mi
    name: events
  iam:
    allowContainerRegistry: true
    legacy: false
  kubelet:
    anonymousAuth: false
  kubernetesApiAccess:
  - 0.0.0.0/0
  - ::/0
  kubernetesVersion: 1.30.2
  networkCIDR: 10.3.0.0/16 #######################
  networking:
    calico: {}
  nonMasqueradeCIDR: 100.64.0.0/10
  sshAccess:
  - 0.0.0.0/0
  - ::/0
  subnets:
  - cidr: 10.3.1.0/24 #######################
    name: ap-northeast-2a
    type: Private
    zone: ap-northeast-2a
  - cidr: 10.3.0.0/24 #######################
    name: utility-ap-northeast-2a
    type: Utility
    zone: ap-northeast-2a
  topology:
    dns:
      type: None
---

# 클러스터 변경 설정 반영 및 실제 생성
[root@~] kops update cluster $cln --yes
```
- Utility subnet
	- 보통 공개적으로 접근 가능한 리소스(예: 로드 밸런서, NAT 게이트웨이)를 위해 사용된다.
- NAT 게이트웨이 생성
	- `kops create cluster --topology private`
	- kops에서 private 토폴로지를 설정하면, 
	  자동으로 private 서브넷, NAT 게이트웨이를 생성한다.
=> 의도했던 대로 생성되었다. 계속 진행하자.

# 5. 클러스터 Desired Capacity 변경
- 클러스터를 삭제하고 다시 삭제해서, 원하는 용량 크기를 다시 수정해야한다.
```sh
[root@~/setup-cluster] kops get ig --name $cln
NAME                            ROLE            MACHINETYPE     MIN     MAX     ZONES
control-plane-ap-northeast-2a   ControlPlane    t3.xlarge       1       1       ap-northeast-2a
nodes-ap-northeast-2a           Node            t3.xlarge       1       1       ap-northeast-2a

# MIN =0, MAX=1
[root@~/setup-cluster] kops edit ig control-plane-ap-northeast-2a --name $cln
[root@~/setup-cluster] kops edit ig nodes-ap-northeast-2a --name $cln

# 변경사항 확인
[root@~/setup-cluster] kops get ig --name $cln
NAME                            ROLE            MACHINETYPE     MIN     MAX     ZONES
control-plane-ap-northeast-2a   ControlPlane    t3.xlarge       0       1       ap-northeast-2a
nodes-ap-northeast-2a           Node            t3.xlarge       0       1       ap-northeast-2a
```

# 6. Autoscaling Group script 적용
```sh
[root@~/setup-cluster] vi aws-asg 
---
cln=team3cluster.lion.nyhhs.com
ig1=control-plane-ap-northeast-2a
# ig2=control-plane-ap-northeast-2b
# ig3=control-plane-ap-northeast-2c
igw1=nodes-ap-northeast-2a
# igw2=nodes-ap-northeast-2b
# igw3=nodes-ap-northeast-2c
aws autoscaling update-auto-scaling-group --auto-scaling-group-name ${ig1}.masters.${cln} --desired-capacity $1
# aws autoscaling update-auto-scaling-group --auto-scaling-group-name ${ig2}.masters.${cln} --desired-capacity $1
# aws autoscaling update-auto-scaling-group --auto-scaling-group-name ${ig3}.masters.${cln} --desired-capacity $1
aws autoscaling update-auto-scaling-group --auto-scaling-group-name ${igw1}.${cln} --desired-capacity $1
---
```
## 6.1. issue
- msg
```sh
An error occurred (ValidationError) when calling the UpdateAutoScalingGroup operation: Desired capacity:0 must be between the specified min size:1 and max size:1
```
- 원인
	- 인스턴스그룹 변경 이전에 클러스터를 생성했었다.
	- 변경 이전에는 MIN=MAX=1 이어서, 스크립트의 desired capacity=0 으로 바꾸는 명령이 실행될 수 없어서 에러가 발생했다.
- 해결방안
	- 인스턴스 그룹 변경사항을 클러스터에 반영 시키고, 스크립트를 실행한다.
```sh
[root@~/setup-cluster] kops update cluster $cln --yes
Cluster changes have been applied to the cloud.
Changes may require instances to restart: kops rolling-update cluster

[root@~/setup-cluster] source aws-asg 0
[root@~/setup-cluster] source aws-asg 1
```

