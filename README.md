# Portable Analytics Stack (FastAPI + Postgres)

Laptop-first setup with health/readiness endpoints, non-root containers, and evidence scripts.

## Dev Quickstart
```powershell
Copy-Item .env.example .env
docker compose --profile dev up -d --build
Invoke-WebRequest http://localhost:8000/health | Out-Null
Invoke-WebRequest http://localhost:8000/ready  | Out-Null
```

App: http://localhost:8000/  
Health: `GET /health` (fast)  
Readiness: `GET /ready` (DB round-trip)

## Prod-like
```powershell
docker compose --profile prod up -d --build
```

## Evidence helpers
```powershell
powershell -File .\ops\measure_ready.ps1
powershell -File .\ops\latency_p95.ps1
docker stats --no-stream
powershell -File .\ops\recovery_rto.ps1
```

## Troubleshooting
- Port 8000 busy → edit `app_dev.ports` in compose.
- `/ready` 503 initially → wait for DB healthcheck; check logs: `docker compose logs -f pgsql`.
- Windows shell quirks → use the PowerShell scripts under `ops/`.
