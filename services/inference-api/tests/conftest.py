from unittest.mock import MagicMock, patch

import pytest

# NER output shape produced by dslim/bert-base-NER with aggregation_strategy="simple"
NER_RESULT = [
    {"word": "Carl Sagan", "entity_group": "PER", "score": 0.9998},
    {"word": "Harvard", "entity_group": "ORG", "score": 0.9752},
    {"word": "Cornell", "entity_group": "ORG", "score": 0.9634},
]

# Patch transformers.pipeline before app.main is imported — prevents 400 MB download in CI
_mock_model = MagicMock(return_value=NER_RESULT)
patch("transformers.pipeline", return_value=_mock_model).start()

# Patch Redis before app.main is imported — prevents connection errors in unit tests
_mock_redis = MagicMock()
_mock_redis.ping.return_value = True
_mock_redis.get.return_value = None  # cache miss by default
_mock_redis.setex.return_value = True
_mock_redis.rpush.return_value = 1
patch("redis.Redis.from_url", return_value=_mock_redis).start()


@pytest.fixture()
def redis_mock():
    """Yield the shared Redis mock, resetting to cache-miss state before each test."""
    _mock_redis.get.return_value = None
    yield _mock_redis


@pytest.fixture(scope="module")
def client():
    """Create a FastAPI TestClient for the app."""
    from app.main import app
    from fastapi.testclient import TestClient

    with TestClient(app) as c:
        yield c


CACHED_RESULT = {
    "entities": [
        {"text": "Carl Sagan", "label": "PER", "score": 0.9998},
        {"text": "Harvard", "label": "ORG", "score": 0.9752},
    ],
    "model": "bert-base-NER",
}
