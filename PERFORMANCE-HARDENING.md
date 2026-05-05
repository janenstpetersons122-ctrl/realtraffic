# RealTraffic — Performance & Resilience Hardening Guide

> Aapka home PC pe heavy-traffic ke liye fully tuned setup. Frontend Vercel pe hai (free), backend + DB sab aapke PC pe Docker mein.

---

## 🎯 Kya Kya Add Hua Hai (Session 7 — Production Hardening)

### 1. Multi-worker Uvicorn (4 workers default, env-tunable)
- `Dockerfile` mein `UVICORN_WORKERS=4` (already tha, ab compose mein bhi env-pass).
- Har worker = separate Python process. Ek busy ho to baaki users ka request continue serve hota hai.
- 16 GB PC pe 4 workers safe; 32 GB pe `UVICORN_WORKERS=8` set kar sakte hain.

### 2. Caddy Rate Limiting + Slow-loris Protection
- `mholt/caddy-ratelimit` plugin se custom Caddy build (`deployment/caddy/Dockerfile`).
- 2 zones:
  - **`auth_burst`**: login/register 10 req / 10 sec per IP → brute-force / credential stuffing rok deta hai.
  - **`global_burst`**: 600 req / 60 sec per IP → bot scrapers limit hote hain.
- HTTP 429 return hota hai jab limit cross hoti hai.
- **Slow-loris drop**: read_body 60s, read_header 10s, idle 120s.
- **Active health check**: backend down ho to Caddy automatic 502 storm ki jagah retry karta hai (`lb_try_duration 5s`).

### 3. Long-running RUT/CPI jobs ke liye:
- **600s upstream timeout** — Cloudflare ka 100s problem solved.
- **Per-worker `HEAVY_JOB_SEMAPHORE`** (default 8) — ek worker mein OOM nahi hoga.
- 4 workers × 8 = **32 concurrent heavy ops** total system mein.
- Existing per-job semaphore (line 7910 in `server.py`) intra-job throttling karta hai.
- ⚠️ **Note**: Full Celery/RQ migration intentionally NAHI kiya — `server.py` 500KB hai, refactor risky tha. Multi-worker + per-worker semaphore practically same isolation deta hai. Future mein agar zaroorat ho to Redis container ready hai.

### 4. Auto-restart on crash (belt + suspenders)
- Docker `restart: unless-stopped` ✅
- `deploy.restart_policy: condition=any, delay=5s, max_attempts=0` (unlimited retry) ✅
- `start_period: 60s` backend ke liye — Playwright init ka time deta hai.
- `pids_limit: 2048` — fork bomb protection.
- `ulimits.nofile: 65535` — file descriptor exhaust nahi hoga.

### 5. MongoDB Connection Pool Tuning
- `maxPoolSize=150` (default 100 tha) — heavy concurrency mein "connection refused" nahi.
- `minPoolSize=20` — warm connections ready, latency kam.
- `maxIdleTimeMS=30000`, `serverSelectionTimeoutMS=10000`.
- `retryWrites=true, retryReads=true` — transient network blip auto-recover.
- `wiredTigerCacheSizeGB=1` Mongo container pe — 16GB host pe predictable.

### 6. Redis Caching Layer (NEW)
- `realtraffic-redis` container, 256MB max, LRU eviction.
- Persistence disabled (`--save ""`) — pure cache, fast.
- Backend ko `REDIS_URL=redis://redis:6379/0` env var via.
- ⚠️ **Currently optional** — backend ne abhi consume nahi kiya; future caching layer ke liye ready.

### 7. Sentry Crash & Performance Monitoring (opt-in)
- `server.py` top mein init block — agar `SENTRY_DSN` env mein set ho to active.
- DSN nahi to graceful no-op (zero overhead).
- FastAPI + Starlette + asyncio integrations.
- 5% transaction sampling default (cost-controlled).
- **Setup**:
  1. Free Sentry account: https://sentry.io/signup/
  2. New project → Python → FastAPI → DSN copy karein.
  3. Apne PC ki `.env` mein:
     ```
     SENTRY_DSN=https://xxxxxxxx@oXXXXXX.ingest.sentry.io/XXXXX
     SENTRY_ENVIRONMENT=production
     SENTRY_TRACES_SAMPLE_RATE=0.05
     ```
  4. `docker compose restart backend`.
- Crash, slow endpoint, error spike — sab Sentry dashboard pe dikhega.

---

## 🚀 Deploy Steps (Aapke PC pe)

### One-time setup
1. **Latest code pull**:
   ```cmd
   cd "F:\online\real flow\..."
   git fetch origin
   git reset --hard origin/main
   ```
2. **`.env` review** (preserve existing values, ya `INSTALL.bat` se naya banaye):
   ```
   BACKEND_DOMAIN=api.yourdomain.com  (or yourname.duckdns.org)
   LE_EMAIL=you@example.com
   ADMIN_PASSWORD=<strong random>
   JWT_SECRET_KEY=<strong random>
   POSTBACK_TOKEN=<strong random>
   UVICORN_WORKERS=4
   HEAVY_JOB_CONCURRENCY=8
   MONGO_MAX_POOL_SIZE=150
   SENTRY_DSN=  (optional)
   ```
3. **Build + start full stack**:
   ```cmd
   docker compose build --no-cache caddy backend
   docker compose up -d
   ```
   Caddy ka custom build pehli baar ~3-5 min lega (Go xcaddy compile).
4. **Verify**:
   ```cmd
   docker compose ps                  (sab "healthy" hone chahiye)
   docker logs realtraffic-backend    ([Mongo] Pool: ... [HeavyJobs] ... print hoga)
   docker logs realtraffic-caddy      ("certificate obtained" dikhna chahiye)
   curl https://api.yourdomain.com/health
   ```

### Routine commands
```cmd
docker compose restart backend       (no rebuild — fast)
docker compose up -d --build backend (after code changes)
docker compose logs -f backend       (live tail)
docker compose down && docker compose up -d  (full restart)
```

---

## 📊 Resource Sizing (16 GB Host)

| Container        | mem_limit | Use                                    |
|------------------|-----------|----------------------------------------|
| backend          | 6 GB      | 4 uvicorn workers + Playwright         |
| mongo            | 2 GB      | DB + WiredTiger cache 1 GB             |
| redis            | 384 MB    | Cache LRU                              |
| caddy            | 384 MB    | Reverse proxy                          |
| ddns-updater     | 64 MB     | Optional                               |
| **Total**        | ~9 GB     | Leaves 7 GB for OS / Chrome / IDE      |

**32 GB upgrade pe**: backend → 12 GB, `UVICORN_WORKERS=8`, `HEAVY_JOB_CONCURRENCY=16`.

---

## 🔒 Rate Limit Tuning (Caddyfile)

- **Default**: 600 global / 60s per IP, 10 auth / 10s per IP.
- Apne traffic pattern ke hisaab se `Caddyfile` mein adjust karein:
  ```
  events 600   →  events 1200   (double)
  window 60s   →  window 30s    (tighter)
  ```
- Whitelist apni admin IP (agar fixed IP):
  ```
  @whitelist remote_ip 1.2.3.4
  rate_limit @whitelist { ... events 999999 ... }
  ```

---

## 🆘 Troubleshooting

### Caddy build fail "xcaddy: not found"
Internet check karein — `caddy:2-builder-alpine` Docker Hub se pull hota hai.

### `429 Too Many Requests` legitimate user ko
`Caddyfile` mein global zone `events` value badhayein → `docker compose restart caddy`.

### Backend `OOM killed` (mem_limit hit)
`docker compose.yml` mein `mem_limit: 6g` → `8g` ya `HEAVY_JOB_CONCURRENCY: 8` → `4` kar dein.

### Mongo "WriteConflict" under heavy write
Already `retryWrites=true` set hai — auto retry hota hai. Persistent ho to Mongo replica set consider karein.

### Sentry "rate-limited"
Default `SENTRY_TRACES_SAMPLE_RATE=0.05` (5%) — agar traffic boht zyada ho to `0.01` (1%) kar dein.

---

## 📈 Future Enhancements (Backlog)

- [ ] Celery + Redis full job queue (decouple heavy ops from API workers)
- [ ] Mongo replica set (HA) for zero-downtime deployments
- [ ] Prometheus + Grafana dashboards (request rate, p95 latency, error rate)
- [ ] Postgres for relational user/org data (Mongo for events/jobs only)
- [ ] CDN for static assets (Cloudflare in front of Vercel)
