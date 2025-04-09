# kafka 개발환경

kafka cluster 구성시에 zookeeper를 사용하는 방식과 KRaft를 사용하는 방식을 나눠서 `docker-compose.yml`파일을 생성하였습니다.

기존 kafka에서는 zookeper를 사용하였으나 최신버전 kfaka 부터는 zookeeper를 사용하지않고 kraft를 사용합니다.

아파치 카프카 3.7 버전이 주키퍼 모드를 지원하는 마지막 버전이고, 이후 카프카 4.0 버전의 경우는 KRaft 모드로만 사용해야 합니다.

zookeeper를 사용하는 샘플은 `kafka 3.3.0`를 기준으로 작성되어있습니다.

([참고자료](https://cwiki.apache.org/confluence/display/KAFKA/KIP-833%3A+Mark+KRaft+as+Production+Ready))

## 개발환경

`.env-sample` 참고하여 개인 설정에 맞는 `.env` 정의가 필요합니다.

## 구성

각 구성도는 폴더면 `README.md`를 확인할 수 있습니다.

- `kafka` : 데이터 수집, 처리 저장하는 데이터 스트리핑 플랫폼입니다.
- `zookeeper` : kafka 코디네이션 서비스입니다.


