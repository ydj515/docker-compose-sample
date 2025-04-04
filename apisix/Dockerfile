FROM apache/apisix:3.11.0-debian

USER root

# Java 설치
RUN apt-get update && apt-get install -y openjdk-17-jre

# 환경 변수 설정
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH="${JAVA_HOME}/bin:${PATH}"
