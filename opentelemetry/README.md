# OpenTelemetry Collector 개발환경

Opentelemetry collector를 별도 구성하고 그에 기반한 trace, metric 및 log 수집

## 개발환경

각 폴더별 서비스의 .env-sample 참고하여 개인 설정에 맞는 .env 정의

## 구성

- `otel-collector` : OpenTelemetry 데이터를 수집(수신), 처리(Processor), 내보내기(Exporter) 역할을 수행하는 핵심 컴포넌트입니다. 다양한 포맷(OTLP, Prometheus 등)을 지원하여 trace, metric, log 데이터를 집계하고 다른 시스템으로 전달합니다.
- `jaeger` : 트레이싱 데이터를 수집하고, 시각화하는 오픈소스 APM 툴입니다.
- `tempo` : trace 스토리지 백엔드입니다.
- `prometheus` : 시계열 기반의 모니터링 툴입니다. 메트릭 데이터를 수집하고 저장합니다.
- `node-exporter` : Prometheus에서 사용하는 대표적인 exporter로, 시스템의 CPU, Memory, Disk 등 자원 상태를 수집합니다.
- `loki` : 로그 집계 저장 시스템입니다. 
- `promtail` : 호스트 또는 컨테이너의 로그 파일을 tail하여 loki로 전송하는 로그 수집기입니다.
- `grafana` : 메트릭, 로그, 트레이스 등 다양한 관측 데이터를 하나의 UI로 통합하여 시각화하는 플랫폼입니다.

```mermaid
graph TD
  subgraph "Tracing & Logging Stack"
    otel["otel-collector"]
    jaeger["jaeger"]
    tempo["tempo"]
    loki["loki"]
    promtail["promtail"]
  end

  subgraph "Observability"
    prometheus["prometheus"]
    grafana["grafana"]
    nodeexporter["node-exporter"]
  end

  %% Connections
  otel -->|OTLP gRPC 4317 / HTTP 4318| jaeger
  otel -->|Metrics| prometheus
  promtail -->|Push Logs| loki
  grafana -->|Query Logs & Metrics| loki
  grafana -->|Query Metrics| prometheus
  grafana -->|Query Traces| tempo
  nodeexporter -->|Exposes Metrics on 9100| prometheus
  prometheus -->|Scrape Metrics| nodeexporter
  otel -->|Expose own metrics 8888| prometheus
  grafana --> otel

  %% External access
  jaeger -->|Web UI :16686| User
  prometheus -->|Web UI :9090| User
  grafana -->|Web UI :3000| User
```


### start with docker compose
1. start docker compose

```sh
cd docker-compose
docker compose up -d # background 실행
```

2. stop docker compose

```sh
docker compose down
docker compose down -v # volume까지 삭제
```

## Telemetry Data 흐름도

![Telemetry Data 흐름도](/assets/otel-col-process.png "Telemetry Data 흐름도")

## 구성요소
### OpenTelemetry Collector
Docker 기반 Collector 설치 및 구동
```sh
docker pull otel/opentelemetry-collector-contrib:0.97.0
docker run -d \
    --name otelcol-0.97.0 \
    --env-file .env \
    -p 1888:1888 `# pprof extension` \
    -p 8888:8888 `# Prometheus metrics exposed by the Collector` \
    -p 8889:8889 `# Prometheus exporter metrics` \
    -p 13133:13133 `# health_check extension` \
    -p 4317:4317 `# OTLP gRPC receiver` \
    -p 4318:4318 `# OTLP http receiver` \
    -v $(pwd)/otel-config.yaml:/etc/otelcol-contrib/config.yaml \
    otel/opentelemetry-collector-contrib:0.97.0
```

### Prometheus
Docker 기반 Prometheus 설치 및 구동(metric 저장 & metric scrapping)
```sh
docker pull prom/prometheus
docker run -d \
    --env-file .env \
    --name prometheus-dev \
    -p 9090:9090 \
    -v $(pwd)/prometheus.yml:/etc/prometheus/prometheus.yml \
    prom/prometheus
```

### Jaeger
Docker 기반 Jaeger 구동(tracing gui)
```sh
docker run -d --rm --name jaeger-dev \
  -p 6831:6831/udp \
  -p 6832:6832/udp \
  -p 5778:5778 \
  -p 16686:16686 \
  -p 4327:4317 `# 동일 machine에서 otel collector와 함께 사용하는 경우 외부 포트 충돌 할 수 있음` \
  -p 4328:4318 `# 동일 machine에서 otel collector와 함께 사용하는 경우 외부 포트 충돌 할 수 있음` \
  -p 14250:14250 \
  -p 14268:14268 \
  -p 14269:14269 \
  -p 9411:9411 \
  jaegertracing/all-in-one:1.56
```

### Grafana
Docker 기반 Grafana 구동
```sh
docker run -d \
  -p 3000:3000 \
  grafana/grafana \
  --name grafana
```

### Tempo
Docker 기반 Tempo 구동(trace 저장)
```sh
docker run -d \
  -p 3200:3200 \
  -p 4317 \
  -p 4318 \
  grafana/tempo:latest \
  --name tempo
```

### node exporter
Docker 기반 node exporter 구동(metric 생성)
```sh
docker run -d \
  -p 9100:9100 \
  quay.io/prometheus/node-exporter:latest \
  --name node-exporter
```