import http from "k6/http";
import { sleep } from "k6";

export const options = {
  vus: __ENV.VUS ? parseInt(__ENV.VUS, 10) : 50,
  duration: __ENV.DURATION || "30s",
};

const BASE = __ENV.BASE_URL || "http://115.145.134.180:8070";

export default function () {
  const url = `${BASE}/health`;

  http.get(url, { timeout: "5s" });

  // 실제 사용자처럼 약간의 think time
  sleep(0.2);
}
