# AWS Network 구성#2
---
# Bastion VPC 생성
- 구성
	- VPC : 1
		- Public subnet : 1

- VPC 생성
	- 이름 : `team3-bastion-VPC`
	- IP : `10.2.0.0/24`
		1. 주소 범위
			1. 시작 주소: 10.2.0.0
			2. 끝 주소: 10.2.0.255
		2. 사용 가능한 호스트 수 : 254개
			1. 첫번째 사용 가능한 호스트 주소: 10.2.0.1
			2. 마지막 사용 가능한 호스트 주소: 10.2.0.254
		3. 브로드캐스트 주소 : 10.2.0.255
		4. 네트워크 클래스 : 클래스 A 사설 IP 주소 범위에 속함
- 퍼블릭 서브넷 생성
	- 이름 : `team3-bastion-VPC-azA-Public-subnet`
	- IP : `10.2.0.0/26`
		- 총 IP 주소 수 : 64개
		- 사용 가능한 IP 주소 수 : 62개
		- 첫 번째 사용 가능한 IP : 10.2.0.1
		- 마지막 사용 가능한 IP : 10.2.0.62
		- 브로드캐스트 주소 : 10.2.0.63
- 퍼블릭 서브넷 라우팅 테이블 생성
	- 이름 : `team3-Bastion-VPC-Public-RouteTable`
	- 서브넷 연결
- 인터넷 게이트웨이 생성
	- 이름 : `team3-bastion-VPC-IGW`
	- VPC 수동 연결 : 하지않을 경우, Detatched 상태로 남는다. ==@issue#1==
- 퍼블릭 서브넷 라우팅 테이블 정책 추가
	- 목적지 : `0.0.0.0/0` 
	- 대상 : 인터넷 게이트웨이 - `team3-bastion-VPC-IGW`

# VPC 연결
- VPC Peering 설정
- 라우팅 테이블 수정
	- Cluster VPC
		- 라우팅 규칙 추가
			- 대상 : `10.2.0.0/24`
			- 대상 : 피어링 연결 `cluster-VPC <> bastion-VPC`
	- Bastion VPC
		- 라우팅 규칙 추가
			- 대상 : `10.1.0.0/16`
			- 대상 : 피어링 연결 `cluster-VPC <> bastion-VPC`
- 테스트 목적, 인스턴스 생성 및 Ping 테스트 : 타임아웃
- @issue#2 VPC 간 네트워크 장애
	- 라우팅 테이블 수정
		- VPC IP 단위로 라우팅 규칙을 추가했었다.
		- 나는 서브넷으로 보내야하니, 서브넷 CIDR 대상으로 라우팅 규칙을 추가해야한다.
		- Bastion-Public-RouteTable
			- 대상 : 10.1.1.0/24
			- 대상 : 피어링 연결 `cluster-VPC <> bastion-VPC`
		- Cluster-Private-RouteTable
			- 대상 : 10.2.0.0/26
			- 대상 : 피어링 연결 `cluster-VPC <> bastion-VPC`
	- 보안 그룹 수정
		- 테스트 목적, 전체 allow
	- 라우팅 테이블 재수정
		- VPC Peering 은 VPC 단위 서비스이기 때문에,
		  피어링 연결을 향한 IP 주소는 상대방 VPC CIDR 여야 한다.
		- Bastion-Public-RouteTable
			- 대상 : 10.1.0.0/16
			- 대상 : 피어링 연결 `cluster-VPC <> bastion-VPC`
		- Cluster-Private-RouteTable
			- 대상 : 10.2.0.0/24
			- 대상 : 피어링 연결 `cluster-VPC <> bastion-VPC`
- 테스트 목적, 인스턴스 생성 및 Ping 테스트 : 정상 확인
