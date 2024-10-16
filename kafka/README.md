# kafka 개발환경

kafka cluster 구성시에 zookeeper를 사용하는 방식과 KRaft를 사용하는 방식을 나눠서 `docker-compose.yml`파일을 생성하였습니다.<br/>
기존 kafka에서는 zookeper를 사용하였으나 최신버전 kfaka 부터는 zookeeper를 사용하지않고 kraft를 사용한다.<br/>
<br/>
아파치 카프카 3.7 버전이 주키퍼 모드를 지원하는 마지막 버전이고, 이후 카프카 4.0 버전의 경우는 KRaft 모드로만 사용해야 합니다.<br/>
<br/>
<br/>
zookeeper를 사용하는 샘플은 `kafka 3.3.0`를 기준으로 작성되어있습니다.

([참고자료](https://cwiki.apache.org/confluence/display/KAFKA/KIP-833%3A+Mark+KRaft+as+Production+Ready))<br/>
