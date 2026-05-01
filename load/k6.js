import { check, sleep } from "k6";
import http from "k6/http";
import { Rate } from "k6/metrics";

const errorRate = new Rate("error_rate");

export const options = {
  stages: [
    { duration: "30s", target: 10 },
    { duration: "1m", target: 50 },
    { duration: "30s", target: 100 },
    { duration: "1m", target: 100 },
    { duration: "30s", target: 0 },
  ],
  thresholds: {
    http_req_duration: ["p(95)<500"],
    error_rate: ["rate<0.01"],
  },
};

const BASE_URL = __ENV.BASE_URL || "http://localhost:8080";

const PAYLOADS = [
  { inputs: [1.0, 2.0, 3.0, 4.0], model_id: "default" },
  { inputs: [0.5, 1.5, 2.5], model_id: "default" },
  { inputs: [10.0, 20.0, 30.0, 40.0, 50.0], model_id: "default" },
  { inputs: [0.1, 0.2, 0.3, 0.4, 0.5, 0.6], model_id: "default" },
];

export default function () {
  const payload = PAYLOADS[Math.floor(Math.random() * PAYLOADS.length)];

  const res = http.post(`${BASE_URL}/infer`, JSON.stringify(payload), {
    headers: { "Content-Type": "application/json" },
  });

  const ok = check(res, {
    "status is 200": (r) => r.status === 200,
    "has prediction field": (r) => {
      try {
        const body = r.json();
        return Array.isArray(body.prediction) && body.prediction.length > 0;
      } catch (_) {
        return false;
      }
    },
    "latency under 200ms": (r) => r.timings.duration < 200,
  });

  errorRate.add(!ok);
  sleep(0.1);
}

export function handleSummary(data) {
  return {
    stdout: JSON.stringify(data, null, 2),
  };
}
