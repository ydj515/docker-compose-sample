// K6_WEB_DASHBOARD=true k6 run --out json=result.json load_test.js
import http from "k6/http";
import { check, sleep } from "k6";

export const options = {
  vus: 100, // 동시 사용자 수
  duration: "3m" // 테스트 실행 시간
};

const BASE_URL = "http://localhost:8080/products";

export default function () {
  // 1 ~ 2000 사이의 랜덤한 ID 생성
  const id = Math.floor(Math.random() * 10000) + 1;
  const res = http.get(`${BASE_URL}/${id}`);

  check(res, {
    "status is 200": (r) => r.status === 200
  });

  sleep(1); // 사용자당 요청 간 간격 (1초)
}
