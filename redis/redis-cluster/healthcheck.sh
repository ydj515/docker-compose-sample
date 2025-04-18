#!/bin/bash

# 클러스터 노드 배열
NODES=(
"redis-node1:7001"
"redis-node2:7002"
"redis-node3:7003"
"redis-node4:7004"
"redis-node5:7005"
"redis-node6:7006"
)

echo "🔍 Redis Cluster 전체 상태 확인"

for node in "${NODES[@]}"
do
  host=$(echo $node | cut -d':' -f1)
  port=$(echo $node | cut -d':' -f2)

  echo ""
  echo "➡️ [$host:$port] 상태 점검 중..."

  # PING 체크
  status=$(redis-cli -h $host -p $port PING)
  if [ "$status" == "PONG" ]; then
    echo "✅ 연결 상태: 정상"
  else
    echo "❌ 연결 상태: 비정상"
    continue
  fi

  # 노드 정보 조회
  redis-cli -h $host -p $port cluster nodes | awk '
  {
    split($2, addr, "@");
    role = $3;
    if (role ~ /master/) {
      printf "💡 Master Node: %s | 상태: %s\n", addr[1], $3;
    } else if (role ~ /slave/) {
      printf "🔹 Slave Node: %s | 상태: %s | 마스터: %s\n", addr[1], $3, $4;
    } else {
      printf "❓ Unknown: %s | 상태: %s\n", addr[1], $3;
    }
  }'

done

echo ""
echo "✅ 전체 Health Check 완료!"