# Kops 기반 k8s cluster 구축 (IaaS)
---
# 1. role 생성과 할당
- 인스턴스에 IAM 역할 할당
	- 대상 : `bastion`
	- 부여 IAM role : `eksworkspace-admin`
- 권한 정책
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "*",
            "Resource": "*"
        }
    ]
}

{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "sts:AssumeRole",
            "Resource": "arn:aws:iam::061039804626:role/eksworkspace-admin"
        }
    ]
}
```
- 신뢰관계
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "ec2.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
```

# 2. Kops/kubectl 설치하기
- 참고자료 : [kops로 쿠버네티스 설치하기_공식문서](https://kubernetes.io/ko/docs/setup/production-environment/tools/kops/)
- kops 설치
```
[root@~] curl -Lo kops https://github.com/kubernetes/kops/releases/latest/download/kops-linux-amd64

[root@~] chmod +x kops

[root@~] mv kops /usr/bin
```
- kubectl 설치
```
[root@~] curl -LO "https://dl.k8s.io/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"

[root@~] chmod +x kubectl

[root@~] mv kubectl /usr/bin
```


# 3. \<skip> Route53 Domain 생성
- 도메인 생성 이유
	- kops는 클러스터 내부와 외부 모두에서 검색을 위해 DNS을 사용하기에 클라이언트에서 쿠버네티스 API 서버에 연결할 수 있다.
	- 이런 클러스터 이름에 kops는 명확한 견해을 가지는데, 반드시 유효한 DNS 이름이어야 한다. 
	- 이렇게 함으로써 사용자는 클러스터를 헷갈리지 않을것이고, 동료들과 혼선없이 공유할 수 있으며, IP를 기억할 필요없이 접근할 수 있다.

# 4. AWS CLI 설치
- [[AWS CLI 설치#^dd14f4]]

## 4.1 Configure 설정
```
[root@~] aws configure
AWS Access Key ID [None]: 
AWS Secret Access Key [None]: 
Default region name [None]: ap-northeast-2
Default output format [None]: json
```
- Access Key ID, Secret Access Key 는 공란으로 넘긴다.
  우리는 인스턴스에 IAM Role을 사전에 부여했다.
  여기서 ID, Key를 설정하면, 사전에 적용한 IAM Role이 적용되는 것이 아니라
  입력한 IAM이 우선으로 적용된다.
  따라서, 의도한 권한을 적용하기 위해서는 공란으로 넘겨야 한다.


# 5. S3 생성 (클러스터 구성 및 상태 저장용)
- kops는 설치 이후에도 클러스터를 관리할 수 있다. 
- 이를 위해 사용자가 생성한 클러스터의 상태나 사용하는 키 정보들을 지속적으로 추적해야 한다. 이 정보가 S3에 저장된다. 
- 이 버킷의 접근은 S3 권한으로 제어한다.
- 다수의 클러스터는 동일한 S3 버킷을 이용할 수 있다.
- 사용자는 이 S3 버킷을 같은 클러스터를 운영하는 동료에게 공유 가능하다.
- S3 버킷에 접근 가능한 사람은 사용자의 모든 클러스터에 관리자 접근이 가능하게 되니, 공유에 주의해야한다.
## 5.1 S3 생성
```
[root@~] aws s3 mb s3://team3cluster.lion2.nyhhs.com

[root@~] aws s3 ls
2024-10-10 04:41:17 team3cluster.lion2.nyhhs.com
```
## 5.2 kops 클러스터의 상태 저장소 위치 설정
```
[root@~] export KOPS_STATE_STORE=s3://team3cluster.lion2.nyhhs.com

[root@~] echo $KOPS_STATE_STORE
s3://team3cluster.lion2.nyhhs.com
```
- kops 는 환경변수 `KOPS_STATE_STORE` 에 설정된 위치를 기본값으로 인식한다.
  해당 내용은 bashrc 에 입력해두는 것을 권장한다.

# 6. 환경변수 설정 (.bashrc)
```shell
[root@~] vi .bashrc
# kops.env
export AWS_PAGER=""
export NAME=team3cluster
export REGION=ap-northeast-2
export KOPS_STATE_STORE="s3://team3cluster.lion2.nyhhs.com"
export MASTER_SIZE="t3.xlarge"
export NODE_SIZE="t3.xlarge"
export ZONES="ap-northeast-2a"
#export ZONES="ap-northeast-2a, ap-northeast-2b"
export cln="team3cluster.lion2.nyhhs.com"

# 적용 및 확인
[root@~] source .bashrc
[root@~] echo $ZONES
ap-northeast-2a
```

# 7. SSH 키 생성
```
[root@~] ssh-keygen
```
- Bastion에서 쿠버네티스 클러스터의 마스터 노드와 워커 노드에 접근하는데 사용되는 SSH 키를 생성한 것이다.
- 생성된 공개키는 kops 설정 과정에서 사용된다.
- 카는 기본적으로 `root/.ssh/id_rsa`(비밀키), `root/.ssh/id_rsa/pub` (공개키) 에 저장된다.

# 8. cluster 설정 생성 script 작성
```shell
[root@~] vi setup-ha-k8s.sh
------------------------------------
export NAME="team3cluster"
export REGION="ap-northeast-2"
export KOPS_STATE_STORE="s3://team3cluster.lion2.nyhhs.com"
export MASTER_SIZE="t3.xlarge"
export NODE_SIZE="t3.xlarge"
export ZONES="ap-northeast-2a"
# export ZONES="ap-northeast-2a,ap-northeast-2b"
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
--topology public \
--ssh-public-key ~/.ssh/id_rsa.pub
------------------------------------

[root@~] chmod +x setup-ha-k8s.sh
```

# 9. Cluster 설정 생성
```shell
[root@~] ./setup-ha-k8s.sh
.
.
.

Must specify --yes to apply changes

Cluster configuration has been created.

Suggestions:
 * list clusters with: kops get cluster
 * edit this cluster with: kops edit cluster team3cluster.lion.nyhhs.com
 * edit your node instance group: kops edit ig --name=team3cluster.lion.nyhhs.com nodes-ap-northeast-2a
 * edit your control-plane instance group: kops edit ig --name=team3cluster.lion.nyhhs.com control-plane-ap-northeast-2a

Finally configure your cluster with: kops update cluster --name team3cluster.lion.nyhhs.com --yes --admin
```
- 스크립트를 실행하면, 클러스터가 바로 생성이 되는 것이 아니다.
  kops 는 클러스터 생성에 사용될 설정을 생성한다.

# (참고)kops 명령 
- 클러스터 조회
  : `kops get cluster`
- 클러스터 수정
  : `kops edit cluster team3cluster.lion.nyhhs.com`
- 클러스터 삭제
  : `kops delete cluster team3cluster.lion.nyhhs.com --yes`
	- `--yes` 를 붙여줘야 실제 삭제가 된다.
- 노드 인스턴스 그룹 수정
  : `kops edit ig --name=team3cluster.lion.nyhhs.com nodes`
- 마스터(컨트롤플레인) 인스턴스 그룹 수정
  : `kops edit ig --name=team3cluster.lion.nyhhs.com master-ap-northeast-2a`

# 10. cluster 확인
```shell
[root@~] kops get clusters --state=s3://team3cluster.lion2.nyhhs.com
NAME                            CLOUD   ZONES
team3cluster.lion.nyhhs.com     aws     ap-northeast-2a

# 인스턴스 그룹 확인
[root@~] kops get instancegroup --name team3cluster.lion.nyhhs.com
NAME                            ROLE            MACHINETYPE     MIN     MAX     ZONES
control-plane-ap-northeast-2a   ControlPlane    t3.xlarge       1       1       ap-northeast-2a
nodes-ap-northeast-2a           Node            t3.xlarge       1       1       ap-northeast-2a

# replica MIN=0, MAX=1 로 수정
[root@~] kops edit instancegroup control-plane-ap-northeast-2a --name team3cluster.lion.nyhhs.com

[root@~] kops edit instancegroup nodes-ap-northeast-2a --name team3cluster.lion.nyhhs.com

# 변경사항 확인
[root@~] kops get instancegroup --name team3cluster.lion.nyhhs.com
NAME                            ROLE            MACHINETYPE     MIN     MAX     ZONES
control-plane-ap-northeast-2a   ControlPlane    t3.xlarge       0       1       ap-northeast-2a
nodes-ap-northeast-2a           Node            t3.xlarge       0       1       ap-northeast-2a
```

# 11. Autoscaling Group script 작성
```shell
[root@~] vi aws-asg
-----------------------------------
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
-----------------------------------

[root@~] chmod +x aws-asg
```

# 12. cluster 실제 생성
```
kops update cluster team3cluster.lion.nyhhs.com --yes
```
- 실행은 수 초 만에 되지만, 실제로 클러스터가 준비되기 전까지 수 분이 걸릴 수 있다.
- 언제든 `kops update cluster`로 클러스터 설정을 변경할 수 있다.
- 사용자가 변경한 클러스터 설정을 그대로 반영해 줄 것이며, 
  필요다하면 AWS 나 쿠버네티스를 재설정 해 줄것이다.
- 예를 들면, `kops edit ig nodes` 뒤에 `kops update cluster --yes`를 실행해 설정을 실제로 반영한다.
- 또한, `kops rolling-update cluster`로 설정을 즉시 원복시킬 수 있다.
- `--yes`를 명시하지 않으면 `kops update cluster` 커맨드 후 어떤 설정이 변경될지가 표시된다. 클러스터 관리 시 매우 유용하다.

# 13. VPC 한도(5개) 도달로 클러스터 생성 오류
-  원인
	- 클러스터 구축 과정에서, 기존 VPC를 사용하는 것이 아니라 새로 생성하여서 한도 도달 발생
- 해결방법
	- 클러스터 생성 스크립트 수정 및 설정 적용
	- 클러스터 실제 생성
	- 불필요 VPC 삭제
	- VPC 한도 증가
```shell
# 스크립트 수정
# VPC_ID, NETWORK_CIDR 추가
[root@~] vi setup-ha-k8s.sh 
---------------------------------
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
---------------------------------

# 스크립트 적용
[root@~] ./setup-ha-k9s.sh

# 클러스터 실제 생성
[root@~] kops update cluster --name team3cluster.lion.nyhhs.com --yes
```
- VPC를 별도 지정하여도, 계속 VPC를 생성하려는 오류가 발생하였다.
- VPC 한도를 기존 5에서 10으로 증량 요청을 한 것이 승인되어 구축을 그대로 진행한다.
  ![[스크린샷 2024-10-10 21.15.58.png|500]]
  ![[스크린샷 2024-10-10 21.34.00.png|500]]
```shell
# 클러스터 실제 생성
[root@~] kops update cluster --name team3cluster.lion.nyhhs.com --yes
Cluster is starting.  It should be ready in a few minutes.

Suggestions:
 * validate cluster: kops validate cluster --wait 10m
 * list nodes: kubectl get nodes --show-labels
 * ssh to a control-plane node: ssh -i ~/.ssh/id_rsa ubuntu@
 * the ubuntu user is specific to Ubuntu. If not using Ubuntu please use the appropriate user based on your OS.
 * read about installing addons at: https://kops.sigs.k8s.io/addons.
```

# 14. Autoscaling Group script 적용
- cluster 생성 시, 인스턴스 그룹의 최소값으 0으로 설정하였다.
  이로 인해서, 클러스터 생성 스크립트가 정상 동작하였여도 인스턴스가 생성되지 않는 상황이다.
- `aws-asg` 실행을 통해서, Desired Capacity 를 변경하여 인스턴스를 생성한다.
- 해당 부분은 콘솔에서도 확인 가능하다.\ ![[Pasted image 20241010221148.png]]
- 이미지에서 알 수 있듯이 원하는 용량이 '0'이다. 이를 변경해준다.
```shell
[root@~] . aws-asg 1
```
![[Pasted image 20241010221303.png]]
- 스크립트 적용 후, 콘솔에서 원하는 용량이 0 -> 1 로 변경 되었음을 확인할 수 있다.

# 15. k8s admin 권한 획득
```shell
[root@~] kops export kubecfg --admin --name team3cluster.lion.nyhhs.com --state s3://team3cluster.lion2.nyhhs.com
kOps has set your kubectl context to team3cluster.lion.nyhhs.com

[root@~] kubectl get nodes
NAME                  STATUS     ROLES           AGE     VERSION
i-050658bd12381435f   NotReady   node            27s     v1.30.2
i-0ab3d3920cb18cabb   Ready      control-plane   3m19s   v1.30.2
```

# 16. kubectx, kubens 설치
```shell
[root@~] git clone https://github.com/ahmetb/kubectx /opt/kubectx

[root@~] ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx

[root@~] ln -s /opt/kubectx/kubens /usr/local/bin/kubens

[root@~] kubectx
team3cluster.lion.nyhhs.com

[root@~] kubens
default
```