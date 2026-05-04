import hashlib
import json
import os
import random
import time
import uuid
from typing import Any, Dict

import redis
from fastapi import FastAPI, HTTPException, Request, Response
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest

APP_NAME = os.getenv("APP_NAME", "inference-api")
REDIS_URL = os.getenv("REDIS_URL", "redis://redis:6379/0")
CACHE_TTL_SECONDS = int(os.getenv("CACHE_TTL_SECONDS", "60"))
RESULT_TTL_SECONDS = int(os.getenv("RESULT_TTL_SECONDS", "600"))
QUEUE_NAME = os.getenv("QUEUE_NAME", "inference:queue")

OTEL_EXPORTER_OTLP_ENDPOINT = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "")

REQS = Counter("inference_requests_total", "Total requests", ["endpoint", "status"])
LATENCY = Histogram("inference_request_latency_seconds", "Latency seconds", ["endpoint", "cache_hit"])
ENQUEUE = Counter("inference_jobs_enqueued_total", "Jobs enqueued total")
JOB_TIME = Histogram("inference_job_processing_seconds", "Worker job processing seconds")

def _setup_tracing() -> None:
    resource = Resource.create({"service.name": APP_NAME})
    provider = TracerProvider(resource=resource)
    trace.set_tracer_provider(provider)

    if OTEL_EXPORTER_OTLP_ENDPOINT:
        exporter = OTLPSpanExporter(endpoint=OTEL_EXPORTER_OTLP_ENDPOINT)
        provider.add_span_processor(BatchSpanProcessor(exporter))


_setup_tracing()
tracer = trace.get_tracer(APP_NAME)

r = redis.Redis.from_url(REDIS_URL, decode_responses=True)

app = FastAPI(title="Online Inference Demo", version="1.1.0")
@app.get("/healthz")
def healthz() -> Dict[str, Any]:
    try:
        pong = r.ping()
        return {"ok": True, "redis": pong}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"redis_unhealthy: {e}")

@app.get("/metrics")
def metrics() -> Response:
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)

def _hash_payload(payload: Dict[str, Any]) -> str:
    raw = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(raw).hexdigest()

def _simulate_inference() -> Dict[str, Any]:
    # cache miss latency simulation (40–80ms)
    time.sleep(random.uniform(0.04, 0.08))
    score = round(random.random(), 6)
    return {"score": score, "model": "demo-v1", "ts": int(time.time())}

@app.post("/infer")
async def infer(request: Request) -> Dict[str, Any]:
    start = time.time()
    try:
        payload = await request.json()
        key = f"infer:{_hash_payload(payload)}"

        with tracer.start_as_current_span("infer.request") as span:
            cached = r.get(key)
            cache_hit = cached is not None
            span.set_attribute("cache.hit", cache_hit)

            if cache_hit:
                LATENCY.labels(endpoint="/infer", cache_hit="true").observe(time.time() - start)
                REQS.labels(endpoint="/infer", status="200").inc()
                return {"cache_hit": True, "result": json.loads(cached)}

            result = _simulate_inference()
            r.setex(key, CACHE_TTL_SECONDS, json.dumps(result))

            LATENCY.labels(endpoint="/infer", cache_hit="false").observe(time.time() - start)
            REQS.labels(endpoint="/infer", status="200").inc()
            return {"cache_hit": False, "result": result}

    except Exception as e:
        REQS.labels(endpoint="/infer", status="500").inc()
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/enqueue")
async def enqueue(request: Request) -> Dict[str, Any]:
    start = time.time()
    try:
        payload = await request.json()
        job_id = str(uuid.uuid4())
        msg = json.dumps({"job_id": job_id, "payload": payload})

        with tracer.start_as_current_span("infer.enqueue") as span:
            span.set_attribute("queue.name", QUEUE_NAME)
            span.set_attribute("job.id", job_id)

            r.rpush(QUEUE_NAME, msg)
            ENQUEUE.inc()

        LATENCY.labels(endpoint="/enqueue", cache_hit="na").observe(time.time() - start)
        REQS.labels(endpoint="/enqueue", status="202").inc()
        return {"accepted": True, "job_id": job_id}

    except Exception as e:
        REQS.labels(endpoint="/enqueue", status="500").inc()
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/result/{job_id}")
def get_result(job_id: str) -> Dict[str, Any]:
    start = time.time()
    try:
        key = f"infer:result:{job_id}"
        val = r.get(key)
        if not val:
            REQS.labels(endpoint="/result", status="404").inc()
            return {"ready": False, "job_id": job_id}

        REQS.labels(endpoint="/result", status="200").inc()
        LATENCY.labels(endpoint="/result", cache_hit="na").observe(time.time() - start)
        return {"ready": True, "job_id": job_id, "result": json.loads(val)}

    except Exception as e:
        REQS.labels(endpoint="/result", status="500").inc()
        raise HTTPException(status_code=500, detail=str(e))
