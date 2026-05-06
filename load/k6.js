import { check, sleep } from "k6";
import http from "k6/http";
import { Counter, Rate, Trend } from "k6/metrics";

const errorRate = new Rate("error_rate");
const cacheHitRate = new Rate("cache_hit_rate");
const inferLatency = new Trend("infer_latency_ms", true);
const enqueueErrors = new Counter("enqueue_errors");

export const options = {
  scenarios: {
    // Sync /infer — ramp up to 100 VUs, mix of cache hits and misses
    sync_infer: {
      executor: "ramping-vus",
      startVUs: 0,
      stages: [
        { duration: "30s", target: 10 },
        { duration: "1m", target: 50 },
        { duration: "30s", target: 100 },
        { duration: "1m", target: 100 },
        { duration: "30s", target: 0 },
      ],
      exec: "inferScenario",
    },
    // Async /enqueue + /result polling — low constant concurrency
    async_enqueue: {
      executor: "constant-vus",
      vus: 5,
      duration: "3m",
      startTime: "30s",
      exec: "enqueueScenario",
    },
  },
  thresholds: {
    // Real DistilBERT inference on CPU; cache hits are <5ms, misses are 100-400ms
    http_req_duration: ["p(95)<3000"],
    // Custom trend covers only /infer calls — tighter signal than the mixed aggregate
    infer_latency_ms: ["p(95)<3000"],
    error_rate: ["rate<0.01"],
    cache_hit_rate: ["rate>0.5"],  // expect majority cache hits under sustained load
    enqueue_errors: ["count<10"],  // tolerate near-zero worker queue timeouts
  },
};

const BASE_URL = __ENV.BASE_URL || "http://localhost:8080";

// Fixed texts — entity-rich sentences cached after first call
const CACHED_TEXTS = [
  "Carl Edward Sagan was born on November 9, 1934, in the Bensonhurst neighborhood of New York City's Brooklyn borough.",
  "Dr. Jaap Haartsen, a Dutch engineer working for Ericsson, is credited with inventing Bluetooth technology in 1994.",
  "Linus Benedict Torvalds[a] (born 28 December 1969) is a Finnish and American software engineer who is the creator and lead developer of the Linux kernel since 1991. He also created the distributed version control system Git.",
  "Rollo, also known with his epithet, Rollo \"the Walker\", was a Viking who, as Count of Rouen, became the first ruler of Normandy, a region in today's northern France.",
  "Robert Leroy Johnson was an American blues singer, guitarist, and songwriter. Known as the \"King of the Delta Blues\" and the \"Grandfather of rock and roll\".",
];

// Returns a unique entity-rich sentence each call — forces a cache miss and real inference
function freshPayload() {
  const orgs = ["Shopify", "Amazon", "Netflix", "Apple", "Virgin Galactic", "Spotify"];
  const people = ["Steve Jobs", "Richard Branson", "Steve Wozniak", "Larry Page"];
  const places = ["Toronto", "Cupertino", "Austin", "Palo Alto", "London"];
  const org = orgs[Math.floor(Math.random() * orgs.length)];
  const person = people[Math.floor(Math.random() * people.length)];
  const place = places[Math.floor(Math.random() * places.length)];
  return { text: `${person} announced that ${org} will expand its operations in ${place} next year — ${Date.now()}.` };
}

export function inferScenario() {
  // 80% cached payloads, 20% fresh to keep the inference path exercised
  const payload =
    Math.random() < 0.8
      ? { text: CACHED_TEXTS[Math.floor(Math.random() * CACHED_TEXTS.length)] }
      : freshPayload();

  const res = http.post(`${BASE_URL}/infer`, JSON.stringify(payload), {
    headers: { "Content-Type": "application/json" },
  });

  const ok = check(res, {
    "infer: status 200": (r) => r.status === 200,
    "infer: has result.entities": (r) => {
      try {
        return Array.isArray(r.json().result?.entities);
      } catch (_) {
        return false;
      }
    },
    "infer: entities have label and score": (r) => {
      try {
        const entities = r.json().result?.entities;
        if (!Array.isArray(entities) || entities.length === 0) return true; // empty is valid
        return typeof entities[0].label === "string" && typeof entities[0].score === "number";
      } catch (_) {
        return false;
      }
    },
  });

  if (res.status === 200) {
    try {
      const body = res.json();
      cacheHitRate.add(body.cache_hit === true);
      inferLatency.add(res.timings.duration);
    } catch (_) {}
  }

  errorRate.add(!ok);
  sleep(0.1);
}

export function enqueueScenario() {
  const payload = { text: CACHED_TEXTS[Math.floor(Math.random() * CACHED_TEXTS.length)] };

  // Step 1: enqueue the job
  const enqRes = http.post(`${BASE_URL}/enqueue`, JSON.stringify(payload), {
    headers: { "Content-Type": "application/json" },
  });

  const enqueued = check(enqRes, {
    "enqueue: status 200": (r) => r.status === 200,
    "enqueue: has job_id": (r) => {
      try {
        return typeof r.json().job_id === "string";
      } catch (_) {
        return false;
      }
    },
  });

  if (!enqueued) {
    enqueueErrors.add(1);
    return;
  }

  const jobId = enqRes.json().job_id;

  // Step 2: poll for result (up to 30 attempts, 1s apart = 30s max wait)
  let ready = false;
  for (let i = 0; i < 30; i++) {
    sleep(1);
    const resultRes = http.get(`${BASE_URL}/result/${jobId}`);
    if (resultRes.status === 200 && resultRes.json().ready) {
      ready = true;
      check(resultRes, {
        "result: has entities": (r) => {
          try {
            return Array.isArray(r.json().result?.entities);
          } catch (_) {
            return false;
          }
        },
      });
      break;
    }
  }

  if (!ready) {
    enqueueErrors.add(1);
  }

  sleep(0.2);
}

// Default export required by k6 — routes to inferScenario when run without scenarios
export default inferScenario;

export function handleSummary(data) {
  return {
    stdout: JSON.stringify(data, null, 2),
  };
}
