#  Redis Sentinel

이 Docker Compose 설정은 다음과 같은 Redis 고가용성(HA) 아키텍처를 구성합니다.

Sentinel은 Redis Master를 감시하고 장애 발생 시 자동으로 Replica를 승격하여 Master Failover를 수행합니다.

- Redis Master 1개
- Redis Replica 2개
- Sentinel 3개

## environment

nothing to do.

## composition

- `redis-master` : Redis Master 노드
- `redis-replica-1` : Redis Replica 노드 1
- `redis-replica-2` : Redis Replica 노드 2
- `sentinel-1` : Sentinel 인스턴스 1
- `sentinel-2` : Sentinel 인스턴스 2
- `sentinel-3` : Sentinel 인스턴스 3

```mermaid
graph TD
    subgraph Redis Cluster
        Master["Redis Master (6379)"]
        Replica1["Redis Replica 1 (6380)"]
        Replica2["Redis Replica 2 (6381)"]
    end

    subgraph Sentinels
        S1["Sentinel 1 (26379)"]
        S2["Sentinel 2 (26380)"]
        S3["Sentinel 3 (26381)"]
    end

    Replica1 -->|replicaof| Master
    Replica2 -->|replicaof| Master

    S1 -->|monitor| Master
    S2 -->|monitor| Master
    S3 -->|monitor| Master
```

## directory structure

```sh
.
├── docker-compose.yml
├── master-data/                      # Redis Master의 AOF 저장 디렉토리
└── sentinel/
    ├── sentinel-1.conf
    ├── sentinel-2.conf
    └── sentinel-3.conf
```

## run
```sh
docker compose up -d
```



굉장히 중요한 부분이 바로 sentinel resolve-hostnames yes 이부분입니다. 이게 없으면 그 다음 행에서 실행되는 sentinel monitor 명령어에서 redis-master를 찾을 수 없습니다. 여기서 redis-master는 마스터 노드의 컨테이너 이름입니다.


### sentinel.conf

- `sentinel resolve-hostnames yes`은 반드시 포함되어야합니다. 이 설정이 없으면  `sentinel monitor` 명령어에서 redis-master를 찾을 수 없습니다.

- `redis-master`는 마스터 노드의 컨테이너 이름입니다.

```sh
port 26379
sentinel resolve-hostnames yes
sentinel monitor mymaster redis-master 6379 2
sentinel down-after-milliseconds mymaster 5000
sentinel parallel-syncs mymaster 1
sentinel failover-timeout mymaster 10000
bind 0.0.0.0
```