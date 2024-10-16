# 회고록

### [241015]
4단계의 점검사항들을 전부 확인하고 MTU를 조정했을 때, 
ping Test 가 정상적으로 되었기에 원인을 MTU 으로 판단했었다.
이를 멘토님에게 말씀 드렸을 때, ”MTU 로 인해서 발생할 문제는 아닌 것 같다” 라고 하셨다.

이에, MTU 를 10,000 byte 까지 키운 다음 ping 테스트를 진행했고, 정상적으로 통신이 되었다.
따라서, MTU 로 인해서 발생하는 문제가 아니었다.

정확한 원인점을 찾기 위해
VMware 의 네트워크 어댑터 설정도 기존 Share with my Mac 으로 변경했다. 이로 인해서, 로컬 VM 의 IP 가 변경 되었다.
변경된 IP에 맞춰서 AWS 에서 라우팅 테이블과, S2S VPN 의 정적경로를 업데이트 해주었다.
그리고 AWS VPN 구성을 다시 다운로드 받았다.

VM IP 만 변경되었기 때문에, VM 에서 다음 파일의 설정만을 변경해주었다.
- `/etc/ipsec.conf`
- `/etc/ipsec.secret`
이후 과정에 대한 점검을 마치고, strongSwan 을 재시작했다.

이이서, Ping 테스트를 진행했고 결과는 정상이었다.

최초, 통신 장애 원인점으로 생각했던
MTU 와 VMware 네트워크 어댑터 원인이 아니었다.

오류 원인점을 특정하기 위해,
구성과정을 기록한 개인 노트를 살펴봤을 때,
VPN 구성 중에 CIDR 오기 또는 VM 라우팅 테이블에 정책이 제대로 등록되지 않은 것으로 인해 문제가 발생한 것으로 추측된다.

오늘 에러 해결 과정에서 Traceroute 를 사용했다.
에러를 해결한 뒤 확인을 해보니, ping 결과와 traceroute 결과가 완전 반대이다.
traceroute 대해 조사해보니, 인터넷 상의 홉(라우터)를 거쳐서 통신하는 과정을 tracking 하는 것이라, 
VPN 연결상태를 확인하는 데는 적절하지 않다는 것을 알게 되었다.

2일 정도 에러 해결을 위해 VPN을 붙잡았다.
이 과정을 통해서 VPN 구성 단계를 단계별로 확인하고,
AWS 에서 온프레미스로 연결되는 네트워크 구성에 대해서 제대로 이해할 수 있었다.

오류 원인점이라고 판단했던 것이 실제 오류점이 아닐 수도 있다는 점이 있다는 것을 깨달을 수 있었다.
오류를 수정하기 위해 이것저것 여러가지를 작업하는 과정에서 오류가 해결 되었고,
실제 오류해결 시점과 다른 시점에 테스트를 함으로써 잘못된 오류점을 판단할 수 있다는 것을 경험했다.

이슈 트래킹 과정을 노트를 하며 따라가기는 했지만,
중간중간 수정점에 대해서 동작 테스트를 안했던 것을 깨달았다.
이슈 트래킹 절차를 더욱 탄탄히, 꼼꼼하게 해야할 것 같다.
이것이 모듈/단위 테스트를 꼭 해야하는 이유인 것인가..? 에 대한 생각도 든다.

더불어, '네트워크에 대한 기초지식이 있었다면 MTU가 원인점이 아니었다는 것을 바로 알 수 있었을텐데..' 라는 생각을 했다.
결국 기초가 중요하다. 기초를 다지자!

---