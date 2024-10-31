# 2024_likelion_Finalproject
---
- 주제 : RHOCP/AWS 를 활용한 하이브리드 클라우드 구축
- 기간 : '24. 9. 30. ~ 11. 1.

- 담당
  - Project Leader (부팀장)
  - AWS에서 네트워크 보안을 고려한 아키텍처 구축
    - Bastion Instance 사용 및 Bastion-Cluster VPC 분리
    - Cluster Private subnet 배치, 보안그룹 등
    - Route53-ACM-AWS ELB 통합을 통한 HTTPS 통신 구현
  - Kops를 활용하여, Control-Plane 종료 가능한 Cluster 구축으로 비용 효율성 향상
  - AWS ELB를 활용하여 클러스터 접근을 위한 로드밸런서 생성 및 부하 분산
  - HPA 생성 및 적용을 통한 Autoscaling 구현
  - On-premise Master DB <- -> AWS DB ReadReplica (RDS) 구축
  - ECR 인증서 갱신 자동화 관련 Cronjob 생성 및 적용
