# AWS Network 구성#1
---
## AWS 네트워크 설계
- VPC  : 2
	- Cluster VPC
		- public subnet : 1
		- Private subnet : 1
	- Bastion VPC
		- Public Subnet : 1

# Kops-cluster-Network
- VPC 생성
	- `team3-kops-cluster-VPC`
	-  `10.1.0.0/16`
		- DNS 확인 활성화
		- DNS 호스트 이름 활성화
- Subnet 생성
	- `team3-cluster-VPC-azA-Public-Subnet` : `10.1.0.0/24`
	- `team3-cluster-VPC-azA-Private-Subnet` : `10.1.1.0/24`
- Network ACL (네트워크 액세스 목록) [보안]
	- 하나 이상의 서브넷에서 들어오고 나가는 트래픽을 제어하기 위한 VPC의 선택적 보안 계층
	- 규칙은 낮은 것부터 높은 것 순으로 트래픽을 평가한다.
	- 트래픽이 어떤 규칙과도 일치하지 않으면 * 규칙이 적용되고, 트래픽은 거부된다.
	- 기본 NACL은 사용자가 별도로 지정하지 않는 한 모든 인/아웃바운드 트래픽을 허용한다.
	- 새 NACL 생성
		- `team3-cluster-VPC-NACL`
	- VPC 내 서브넷과 연결
		- 기본적으로 모든 인바운드 규칙이 거부되어있다.
	- 인/아웃 바운드 규칙 설정
		- 우선, 모든 트래픽/소스 허용
		- ==추후, Bastion과 앱 관련 접속 트래픽만 허용하도록 변경 필요==
- 라우팅 테이블
	- 퍼블릭 서브넷 라우팅 테이블을 새로 생성
		- 현재는 local 경로만 존재, 
		  추후 인터넷 게이트웨이를 생성하고 경로를 추가하여 인터넷 액세스가 가능하도록 할 예정
	- 생성한 퍼블릭 서브넷 라우팅 테이블과 퍼블릭 서브넷 연결
	- 프라이빗 서브넷 라우팅 테이블 새로 생성
		- 현재는 local 경로만 존재,
		  추후 NAT 게이트웨이를 통해 인터넷으로의 경로를 추가하여 아웃바운드 인터넷 액세스를 활성화 예정
	- 프라이빗 서브넷 라우팅 테이블과 프라이빗 서브넷 연결
- 인터넷 게이트웨이
	- VPC에 배포되는 EC2 인스턴스에 대한 외부 연결을 설정
	- 퍼블릭 서브넷에서 실행되는 워크로드에 대한 인/아웃 바운드 연결을 제공한다.
	- 인터넷 게이트웨이 생성
		- `team3-cluster-VPC-IGW`
	- VPC 연결
	- VPC에 대한 인터넷 액세스 포인트가 생겼지만, 
	  새로 만든 인터넷 게이트웨이를 활용하려면, 
	  퍼블릭 서브넷의 기본 경로가 생성한 인터넷 게이트웨이를 가리키도록 
	  VPC 라우팅 테이블을 업데이트 해야한다.
		- 퍼블릭 라우팅 테이블의 라우팅 편집
			- 목적지 : `0.0.0.0/0` 
			- 대상 : 인터넷 게이트웨이 - `team3-cluster-VPC-IGW`
- NAT 게이트웨이
	- 프라이빗 서브넷에서 실행되는 워크로드에 대한 아웃바운드 연결을 제공한다.
	- 활용되는 각 AZ 에 NAT 게이트웨이를 만드는 것을 권장한다.
	- NAT 게이트웨이 생성
		- 이름 : `team3-cluster-VPC-NATGW`
		- 서브넷 (NAT 게이트웨이를 생성할) : `team3-cluster-VPC-azA-Public-Subnet`
		- 탄력적 IP 할당 : `test-elastic-ip`
- 프라이빗 서브넷 라우팅 테이블 업데이트
	- NAT 게이트웨이가 퍼블릭 서브넷에 존재하기 때문에,
	  프라이븟 서브넷에서 NAT 게이트웨이로 가는 경로를 생성 해야한다.
	- 목적지 : `0.0.0.0/0`
	- 대상 : NAT 게이트웨이 : `team3-cluster-VPC-NATGW`