# Site-to-Site VPN 구성 : AWS <-> local VM
| 참고 자료 : https://www.youtube.com/watch?v=XonAC_Z9s8Y

# 1. AWS
## 1.1 고객 게이트웨이 생성
- team3-CGW
- 내 공인 IP : 221.167.228.30

## 1.2 가상 프라이빗 게이트웨이 생성
- team3-VPG
- VPC 연결 : `team3cluster.lion.nyhhs.com`
## 1.3 Site-to-Site VPN 생성
- 가상 프라이빗 게이트웨이 지정
- 고객 게이트웨이 지정
- 라우팅 옵션 지정 : 정적
- 내 로컬 IP prefix  확인
	- VM 네트워크 어댑터를 ==기존 Share with my Mac -> wifi 로 변경== 후 확인 ![[Pasted image 20241015142007.png]]
```sh
# VM에서
sb@team3:~$ ifconfig
ens160: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 192.168.35.81  netmask 255.255.255.0  broadcast 192.168.35.255
        inet6 fe80::20c:29ff:fe0d:298  prefixlen 64  scopeid 0x20<link>
        ether 00:0c:29:0d:02:98  txqueuelen 1000  (Ethernet)
        RX packets 99511  bytes 121144135 (121.1 MB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 27638  bytes 3222957 (3.2 MB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
        device interrupt 46  memory 0x3fe00000-3fe20000  
```
- 정적IP 접두사 (Prefix) 입력
	- VM : `192.168.35.0/24`

## 1.4 VPN 구성 다운로드
- strongSwan

---
# 2. VM
## 2.1 strongSwan 설치
```shell
sudo apt install strongswan
```
## 2.2 설정파일 작성/수정
- `/etc/sysctl.conf`
```sh
sudo vi /etc/sysctl.conf
---
...

# 주석해제
net.ipv4.ip_forward=1

...
---

# 변경사항 적용
sudo sysctl -p
```
- `/etc/ipsec.conf`
```sh
# 주석해제
uniqueids = no
...

# leftupdown 주석 해제
# <VPC CIDR> 칸에 연결하려는 VPC CIDR 값 넣기
# conn Tunnel1 섹션 붙여넣기
# Tunnel2 도 동일하게 수정 후 붙여넣기
conn Tunnel1
	auto=start
	left=%defaultroute
	leftid=221.167.228.30
	right=3.34.172.145
	type=tunnel
	leftauth=psk
	rightauth=psk
	keyexchange=ikev1
	ike=aes128-sha1-modp1024
	ikelifetime=8h
	esp=aes128-sha1-modp1024
	lifetime=1h
	keyingtries=%forever
	leftsubnet=0.0.0.0/0
	rightsubnet=0.0.0.0/0
	dpddelay=10s
	dpdtimeout=30s
	dpdaction=restart
	## Please note the following line assumes you only have two tunnels in your Strongswan configuration file. This "mark" value must be unique and may need to be changed based on other entries in your configuration file.
	mark=100
	## Uncomment the following line to utilize the script from the "Automated Tunnel Healhcheck and Failover" section. Ensure that the integer after "-m" matches the "mark" value above, and <VPC CIDR> is replaced with the CIDR of your VPC
	## (e.g. 192.168.1.0/24)
	leftupdown="/etc/ipsec.d/aws-updown.sh -ln Tunnel1 -ll 169.254.178.94/30 -lr 169.254.178.93/30 -m 100 -r 10.3.0.0/16"
```
- `etc/ipsec.secrets`
```sh
# Tunnel 1,2 PSK 값 붙여넣기
#Tunnel 1
221.167.228.30 3.34.172.145 : PSK "3Nwdw9opbkYfIDOmwLIBU0uINPvq_O2L"
#Tunnel 2
221.167.228.30 43.200.52.10 : PSK "zSsBH6qblDl6mBqYxWjl6fo0lZlWO.DE"
```
- `/etc/ipsec.d/aws-updown.sh` 작성
```sh
sudo vi /etc/ipsec.d/aws-updown.sh
---
#!/bin/bash

while [[ $# > 1 ]]; do
	case ${1} in
		-ln|--link-name)
			TUNNEL_NAME="${2}"
			TUNNEL_PHY_INTERFACE="${PLUTO_INTERFACE}"
			shift
			;;
		-ll|--link-local)
			TUNNEL_LOCAL_ADDRESS="${2}"
			TUNNEL_LOCAL_ENDPOINT="${PLUTO_ME}"
			shift
			;;
		-lr|--link-remote)
			TUNNEL_REMOTE_ADDRESS="${2}"
			TUNNEL_REMOTE_ENDPOINT="${PLUTO_PEER}"
			shift
			;;
		-m|--mark)
			TUNNEL_MARK="${2}"
			shift
			;;
		-r|--static-route)
			TUNNEL_STATIC_ROUTE="${2}"
			shift
			;;
		*)
			echo "${0}: Unknown argument \"${1}\"" >&2
			;;
	esac
	shift
done

command_exists() {
	type "$1" >&2 2>&2
}

create_interface() {
	ip link add ${TUNNEL_NAME} type vti local ${TUNNEL_LOCAL_ENDPOINT} remote ${TUNNEL_REMOTE_ENDPOINT} key ${TUNNEL_MARK}
	ip addr add ${TUNNEL_LOCAL_ADDRESS} remote ${TUNNEL_REMOTE_ADDRESS} dev ${TUNNEL_NAME}
	ip link set ${TUNNEL_NAME} up mtu 1419
}

configure_sysctl() {
	sysctl -w net.ipv4.ip_forward=1
	sysctl -w net.ipv4.conf.${TUNNEL_NAME}.rp_filter=2
	sysctl -w net.ipv4.conf.${TUNNEL_NAME}.disable_policy=1
	sysctl -w net.ipv4.conf.${TUNNEL_PHY_INTERFACE}.disable_xfrm=1
	sysctl -w net.ipv4.conf.${TUNNEL_PHY_INTERFACE}.disable_policy=1
}

add_route() {
	IFS=',' read -ra route <<< "${TUNNEL_STATIC_ROUTE}"
    	for i in "${route[@]}"; do
	    ip route add ${i} dev ${TUNNEL_NAME} metric ${TUNNEL_MARK} ==src 192.168.35.81== #와이파이 IP 넣었다가, 통신이 되지 않아서 VM IP 입력했다.
	done
	iptables -t mangle -A FORWARD -o ${TUNNEL_NAME} -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
	iptables -t mangle -A INPUT -p esp -s ${TUNNEL_REMOTE_ENDPOINT} -d ${TUNNEL_LOCAL_ENDPOINT} -j MARK --set-xmark ${TUNNEL_MARK}
	ip route flush table 220
}

cleanup() {
        IFS=',' read -ra route <<< "${TUNNEL_STATIC_ROUTE}"
        for i in "${route[@]}"; do
            ip route del ${i} dev ${TUNNEL_NAME} metric ${TUNNEL_MARK}
        done
	iptables -t mangle -D FORWARD -o ${TUNNEL_NAME} -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
	iptables -t mangle -D INPUT -p esp -s ${TUNNEL_REMOTE_ENDPOINT} -d ${TUNNEL_LOCAL_ENDPOINT} -j MARK --set-xmark ${TUNNEL_MARK}
	ip route flush cache
}

delete_interface() {
	ip link set ${TUNNEL_NAME} down
	ip link del ${TUNNEL_NAME}
}

# main execution starts here

command_exists ip || echo "ERROR: ip command is required to execute the script, check if you are running as root, mostly to do with path, /sbin/" >&2 2>&2
command_exists iptables || echo "ERROR: iptables command is required to execute the script, check if you are running as root, mostly to do with path, /sbin/" >&2 2>&2
command_exists sysctl || echo "ERROR: sysctl command is required to execute the script, check if you are running as root, mostly to do with path, /sbin/" >&2 2>&2

case "${PLUTO_VERB}" in
	up-client)
		create_interface
		configure_sysctl
		add_route
		;;
	down-client)
		cleanup
		delete_interface
		;;
esac
---

# 권한 변경
sudo chmod 744 /etc/ipsec.d/aws-updown.sh
```
- strongswan 재시작
  : `sudo ipsec status`
## 2.3 VPN Tunnel 확인
```sh
sudo ipsec status
sudo ifconfig
```

## 2.4 라우팅 테이블 확인
```sh
sudo ip route
```

---
# 3. AWS

## 3.1 VPN 터널 상태 up 확인
- up 확인
## 3.2 인스턴스 생성
- VPC : team3cluster.lion.nyhhs.com
- 보안그룹
	- SSH - Any Allow
	- ICMP - Any Allow
## 3.3 라우팅 테이블 확인
- 라우팅테이블 : `team3cluster.lion.nyhhs.com 
- 라우팅 규칙 추가
	- 로컬 IP : 192.168.35.0/24
	- 가상 프라이빗 게이트웨이

---
# 4. Ping 테스트
- 생성 인스턴스 프라이빗IP 으로  Ping
- 통신이 되지 않는다.
## 4.1 점검사항
- AWS VPC 라우팅 테이블
- 보안그룹
- 네트워크 ACL
- VPN 연결상태 모두 트래픽이 
- 허용 설정 되어있어. 상태도 정상으로 확인 완료
---
# 5. 해결 방법
- ==MTU 설정 조정:==
	- VPN 연결의 MTU 값을 조정. => 1400
```
sb@team3:~$ sudo ip link set dev Tunnel1 mtu 1400
sb@team3:~$ sudo ip link set dev Tunnel2 mtu 1400
```
- ping test
```sh
sb@team3:~$ ping 10.3.0.179
PING 10.3.0.179 (10.3.0.179) 56(84) bytes of data.
64 bytes from 10.3.0.179: icmp_seq=1 ttl=64 time=11.5 ms
64 bytes from 10.3.0.179: icmp_seq=2 ttl=64 time=9.32 ms
64 bytes from 10.3.0.179: icmp_seq=3 ttl=64 time=9.56 ms
64 bytes from 10.3.0.179: icmp_seq=4 ttl=64 time=10.1 ms
64 bytes from 10.3.0.179: icmp_seq=5 ttl=64 time=9.79 ms
64 bytes from 10.3.0.179: icmp_seq=6 ttl=64 time=9.24 ms
^C
--- 10.3.0.179 ping statistics ---
6 packets transmitted, 6 received, 0% packet loss, time 5013ms
rtt min/avg/max/mdev = 9.239/9.916/11.503/0.764 ms
```
---
# 7. 회고
- 에러 해결 과정에서 Traceroute 를 사용했다.
  에러를 해결한 뒤 확인을 해보니, ping 결과와 traceroute 결과가 완전 반대이다.
  traceroute는 인터넷 상의 라우터를 거쳐서 통신한느 과정을 tracking 하는 것이라, VPN 연결상태를 확인하는 데는 적절하지 않다고 생각된다.
- VPN 구성 단계를 단계별로 확인하고,
  그 과정에서 AWS VPN 구성에 대해서 제대로 이해할 수 있었다.
  더불어, 로컬 네트워크 구성에 대한 고민하고 파악할 수 있었다.
  VPN을 여러 번 구성하고, 점검점/오류발생점을 추측하고 알아보며 해결할 수 있었다.
  에러 해결에 2일 정도 소요되었지만, 결국 나의 논리가 들어맞았고, 에러를 해결할 수 있었던 것에 대해 성취감을 얻었다.
- MTU 크기로 에러가 해결되었다.
  네트워크 기초에 대한 이해가 부족한 것 같다.
  다시 학습하자.