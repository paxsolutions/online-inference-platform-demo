import json
import os
import time

import redis
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from prometheus_client import Counter, Histogram, start_http_server
from transformers import pipeline

_model = pipeline(
    "ner",
    model="dslim/bert-base-NER",
    aggregation_strategy="first"
)

APP_NAME = os.getenv("APP_NAME", "inference-worker")
REDIS_URL = os.getenv("REDIS_URL", "redis://redis:6379/0")
QUEUE_NAME = os.getenv("QUEUE_NAME", "inference:queue")
RESULT_TTL_SECONDS = int(os.getenv("RESULT_TTL_SECONDS", "600"))
OTEL_EXPORTER_OTLP_ENDPOINT = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "")
METRICS_PORT = int(os.getenv("METRICS_PORT", "9100"))

JOBS = Counter("worker_jobs_total", "Jobs processed", ["status"])
JOB_TIME = Histogram("worker_job_processing_seconds", "Job processing seconds")

def setup_tracing():
    """Setup OpenTelemetry tracing."""
    resource = Resource.create({"service.name": APP_NAME})
    provider = TracerProvider(resource=resource)
    trace.set_tracer_provider(provider)
    if OTEL_EXPORTER_OTLP_ENDPOINT:
        exporter = OTLPSpanExporter(endpoint=OTEL_EXPORTER_OTLP_ENDPOINT)
        provider.add_span_processor(BatchSpanProcessor(exporter))

def run_inference(payload: dict) -> dict:
    """Run NER inference and return grouped entities."""
    text = payload.get("text", "")
    entities = _model(text)
    return {
        "entities": [
            {
                "text": e["word"],
                "label": e["entity_group"],
                "score": round(float(e["score"]), 4),
            }
            for e in entities
        ],
        "model": "bert-base-NER",
    }

def main():
    """Main worker loop."""
    setup_tracing()
    tracer = trace.get_tracer(APP_NAME)
    r = redis.Redis.from_url(REDIS_URL, decode_responses=True)

    start_http_server(METRICS_PORT)
    print(f"[worker] metrics on :{METRICS_PORT}, queue={QUEUE_NAME}")

    while True:
        # BLPOP blocks until a message arrives
        item = r.blpop(QUEUE_NAME, timeout=5)
        if not item:
            continue

        _, msg = item
        start = time.time()

        try:
            data = json.loads(msg)
            job_id = data["job_id"]
            payload = data["payload"]

            with tracer.start_as_current_span("infer.worker") as span:
                span.set_attribute("queue.name", QUEUE_NAME)
                span.set_attribute("job.id", job_id)

                result = run_inference(payload)
                span.set_attribute("model.entity_count", len(result["entities"]))
                result["input"] = payload  # helpful for demo visibility

                r.setex(f"infer:result:{job_id}", RESULT_TTL_SECONDS, json.dumps(result))

            JOBS.labels(status="ok").inc()
            JOB_TIME.observe(time.time() - start)

        except Exception as e:
            JOBS.labels(status="error").inc()
            print(f"[worker] error: {e}")

if __name__ == "__main__":
    main()
