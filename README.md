# Online Inference Platform Demo (Kubernetes + OpenTelemetry)

A production-minded demo that mirrors real-time inference infrastructure:

- FastAPI inference service with Redis cache-aside
- OpenTelemetry tracing -> OTel Collector -> Jaeger
- Prometheus metrics + Grafana dashboard
- Kubernetes deploy (kind) + HPA autoscaling
- Helm chart packaging

## Run on Kubernetes (kind)

```bash
kind create cluster --name inference
docker build -t inference-api:local ./services/inference-api
kind load docker-image inference-api:local --name inference

kubectl apply -f deploy/k8s/00-namespace.yaml
kubectl apply -f deploy/k8s/10-redis.yaml
kubectl apply -f deploy/k8s/20-inference-api.yaml
kubectl apply -f deploy/k8s/25-inference-worker.yaml
kubectl apply -f deploy/k8s/26-inference-worker-svc.yaml
kubectl apply -f deploy/k8s/30-otel-collector.yaml
kubectl apply -f deploy/k8s/40-jaeger.yaml
kubectl apply -f deploy/k8s/50-prometheus.yaml
kubectl apply -f deploy/k8s/60-grafana.yaml
kubectl apply -f deploy/k8s/70-hpa.yaml
```

## Port forwarding

```bash
kubectl -n inference port-forward svc/inference-api 8080:80

kubectl -n inference port-forward svc/jaeger 16686:16686

kubectl -n inference port-forward svc/grafana 3000:3000

kubectl -n inference port-forward svc/inference-worker 9100:9100
```

## Run locally (Docker Compose)

```bash
docker compose up --build
```

## Sanity check

```bash
curl http://localhost:8080/healthz

curl -X POST http://localhost:8080/infer \
  -H "Content-Type: application/json" \
  -d '{"userId":"123","itemId":"abc"}'

curl -X POST http://localhost:8080/infer \
  -H "Content-Type: application/json" \
  -d '{"userId":"123","itemId":"abc"}'  # should be cache_hit true on second call
```

## Test event-driven flow

```bash
# Enqueue a job
curl -X POST http://localhost:8080/enqueue \
  -H "Content-Type: application/json" \
  -d '{"userId":"123","itemId":"abc"}'

# Infer with a random ID (should not be cached)
curl -X POST http://localhost:8080/infer \
  -H "Content-Type: application/json" \
  -d '{"userId":"123","itemId":"<some-random-id>"}' # should be cache_hit true on second call
```

## UI

See traces:

- Jaeger UI: http://localhost:16686
  - service: inference-api

See metrics:

- Grafana: http://localhost:3000
  - admin/admin

## Load test + autoscaling

```bash
k6 run load/k6.js
kubectl -n inference get hpa -w
```

## Helm

```bash
helm lint charts/online-inference
helm install inference charts/online-inference -n inference --create-namespace
```
