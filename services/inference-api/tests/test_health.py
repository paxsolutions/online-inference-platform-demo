import json

CACHED_RESULT = {
    "entities": [
        {"text": "Carl Sagan", "label": "PER", "score": 0.9998},
        {"text": "Harvard",    "label": "ORG", "score": 0.9752},
    ],
    "model": "bert-base-NER",
}

# ---------------------------------------------------------------------------
# /healthz
# ---------------------------------------------------------------------------

def test_healthz_ok(client, redis_mock):
    resp = client.get("/healthz")
    assert resp.status_code == 200
    body = resp.json()
    assert body["ok"] is True
    assert body["redis"] is True


# ---------------------------------------------------------------------------
# /metrics
# ---------------------------------------------------------------------------

def test_metrics_returns_prometheus_text(client):
    resp = client.get("/metrics")
    assert resp.status_code == 200
    assert "text/plain" in resp.headers["content-type"]
    # Prometheus exposition format always starts with a comment or metric name
    assert resp.text.strip() != ""


# ---------------------------------------------------------------------------
# /infer
# ---------------------------------------------------------------------------

def test_infer_cache_miss_returns_ner_entities(client, redis_mock):
    redis_mock.get.return_value = None  # force cache miss

    resp = client.post("/infer", json={"text": "Carl Sagan studied at Harvard and Cornell."})

    assert resp.status_code == 200
    body = resp.json()
    assert body["cache_hit"] is False
    entities = body["result"]["entities"]
    assert isinstance(entities, list)
    assert len(entities) > 0
    for e in entities:
        assert "text" in e
        assert "label" in e
        assert "score" in e
        assert isinstance(e["score"], float)


def test_infer_cache_hit_skips_model(client, redis_mock):
    redis_mock.get.return_value = json.dumps(CACHED_RESULT)  # warm cache

    resp = client.post("/infer", json={"text": "Carl Sagan studied at Harvard and Cornell."})

    assert resp.status_code == 200
    body = resp.json()
    assert body["cache_hit"] is True
    assert body["result"]["model"] == "bert-base-NER"
    assert isinstance(body["result"]["entities"], list)


def test_infer_missing_text_returns_422(client, redis_mock):
    resp = client.post("/infer", json={"query": "no text field here"})
    assert resp.status_code == 422


def test_infer_empty_body_returns_error(client):
    resp = client.post("/infer", content=b"", headers={"Content-Type": "application/json"})
    assert resp.status_code in (400, 422, 500)


# ---------------------------------------------------------------------------
# /enqueue
# ---------------------------------------------------------------------------

def test_enqueue_returns_job_id(client, redis_mock):
    resp = client.post("/enqueue", json={"text": "NASA launched Artemis from Cape Canaveral."})

    assert resp.status_code == 200
    body = resp.json()
    assert body["accepted"] is True
    assert isinstance(body["job_id"], str)
    assert len(body["job_id"]) == 36  # UUID4 format


def test_enqueue_calls_redis_rpush(client, redis_mock):
    redis_mock.rpush.reset_mock()
    client.post("/enqueue", json={"text": "OpenAI is headquartered in San Francisco."})
    redis_mock.rpush.assert_called_once()


# ---------------------------------------------------------------------------
# /result/{job_id}
# ---------------------------------------------------------------------------

def test_result_pending_when_not_ready(client, redis_mock):
    redis_mock.get.return_value = None  # job not yet written by worker

    resp = client.get("/result/some-fake-job-id")

    assert resp.status_code == 200
    body = resp.json()
    assert body["ready"] is False
    assert body["job_id"] == "some-fake-job-id"


def test_result_complete_when_ready(client, redis_mock):
    stored = json.dumps({**CACHED_RESULT, "input": {"text": "Carl Sagan studied at Harvard."}})
    redis_mock.get.return_value = stored

    resp = client.get("/result/some-fake-job-id")

    assert resp.status_code == 200
    body = resp.json()
    assert body["ready"] is True
    assert body["job_id"] == "some-fake-job-id"
    assert isinstance(body["result"]["entities"], list)
    assert body["result"]["model"] == "bert-base-NER"
