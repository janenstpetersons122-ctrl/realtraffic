# RealTraffic (formerly RealFlow) — PRD

## Original Problem Statement
> User cloned `lenovogen03/lenovo-realflow` into `/app`, wants to iterate on features and push back to `main`. Pain points raised:
> 1. Real User Traffic jobs are slow on 16 GB home PC Docker
> 2. "Network aborted twice + 60s recovery poll failed" error on big jobs (Cloudflare tunnel 100s timeout)
> 3. Wants to fully rebrand RealFlow → RealTraffic
> 4. Wants new Docker setup isolated from existing other Docker project on the same 16 GB host
> 5. Eventually wants to drop Cloudflare and self-host on home PC (Nayatel public IP, Namecheap domain) — guide prepared, not yet migrated.

## Tech Stack
- **Backend**: FastAPI, Motor (MongoDB async), Playwright, Selenium, bcrypt+passlib auth, emergentintegrations, Stripe, Resend, Google APIs, Appium, pymobiledevice3.
- **Frontend**: React 18 + CRA (craco), Tailwind, shadcn/ui (Radix), react-router v7, axios, recharts.
- **Database**: MongoDB (Docker on home PC in prod, supervisor-managed locally).
- **Deploy target**: Docker Compose on Nayatel Windows 11 home PC. Frontend on Vercel. Cloudflare Tunnel currently bridges; migration to direct Nayatel public IP + Namecheap DDNS + Nginx Proxy Manager planned.

## Core Modules (all loaded, tested green)
- Auth (user + admin + sub-users + password reset)
- Real User Traffic (RUT) — headless Chromium farm w/ anti-detect, shared browser + per-visit context
- Form Filler — SOI / lead-form automation (smart + custom-JSON modes)
- CPI Install Module (offers, jobs, devices, smart links, worker setup)
- User Agent Generator / Checker / Referrer Stats / Email Checker
- Branding / Admin Dashboard / Admin System Check
- Google Sheets live sync + email notifications (SMTP / Resend)

## Sessions Summary

### Session 1 (2026-01) — Clone + Baseline
- Cloned repo into `/app`, installed `pip` + `yarn` deps.
- Created `backend/.env` + `frontend/.env`, restarted supervisor.
- Smoke test (iter_3): **18/18 PASS**, zero critical.

#### Session 5 (2026-01) — DuckDNS-based zero-cost setup (no custom domain)

User clarified one final time: **NO custom domain**, wants to use Vercel's free `*.vercel.app` domain for frontend AND wants backend public via free DDNS service. Solution: **DuckDNS** (free `*.duckdns.org` subdomain — works perfectly with Let's Encrypt HTTP-01 challenge via Caddy).

`INSTALL.bat` simplified to 3 prompts:
1. DuckDNS subdomain (e.g. `myrealtraffic` → `myrealtraffic.duckdns.org`)
2. DuckDNS token (from duckdns.org dashboard)
3. Email (Let's Encrypt notifications)

After 5-10 min build user does TWO manual one-time steps:
1. Huawei port forward 80 + 443
2. Vercel deploy with `REACT_APP_BACKEND_URL=https://myrealtraffic.duckdns.org`

Files updated:
- `INSTALL.bat` — DuckDNS-first prompt flow, auto-writes `.env` + `ddns-config/config.json` for `qmcgaw/ddns-updater` provider=`duckdns`, builds + starts `--profile ddns` so the DDNS updater container always runs.
- `README.md` — 4-step Hindi/Urdu walkthrough specific to DuckDNS + Vercel free domain.
- `docker-compose.yml` — unchanged (already had ddns-updater service and Caddy depending on it).

Total cost: ₹0/month. No custom domain, no Cloudflare, no ngrok paid plan.

User flow recap:
- DuckDNS signup + create subdomain (30 sec)
- Vercel signup + import repo (1 min)
- Run INSTALL.bat once (10 min build + 3 prompts)
- Huawei port forward (5 min)
- Vercel "Deploy" button (5 min)
- Done — `https://lenovo-realflow.vercel.app` accessible globally.

### Session 4 (2026-01) — Final architecture: Vercel frontend + home PC backend with Caddy auto-SSL

User decided definitively: **Vercel hosts frontend (free public access), home PC Docker hosts backend stack with auto Let's Encrypt SSL**. Public users login from anywhere via single Vercel URL.

Final stack rewritten:
```
[Browser anywhere]
       │ https://lenovo-realflow.vercel.app
       ▼
[Vercel CDN — frontend (auto-deploys from main branch)]
       │ API → REACT_APP_BACKEND_URL = https://api.yourdomain.com
       ▼
[Namecheap DNS A record → Nayatel public IP]
       │
       ▼
[Huawei Router: port 443 → home PC LAN IP]
       │
       ▼
[Home PC Docker]
   ├─ realtraffic-caddy   :80/:443  (auto Let's Encrypt SSL, reverse proxy)
   ├─ realtraffic-backend :8001     (internal — only via Caddy)
   ├─ realtraffic-mongo              (internal)
   └─ realtraffic-ddns               (Namecheap DDNS auto-update, optional profile)
```

Files added/updated:
- `docker-compose.yml` — services: mongo + backend + caddy + ddns-updater. Caddy on host 80/443, backend internal-only. DDNS updater runs as `--profile ddns` (auto-enabled by INSTALL.bat when password supplied). All `realtraffic-*` prefixed.
- `Caddyfile` — single host block: `{$BACKEND_DOMAIN}` reverse-proxies to `backend:8001`, auto Let's Encrypt, gzip+zstd encoding, security headers (HSTS, X-Frame-Options, etc.), 100 MB request body cap, 600s read/write timeouts for long RUT jobs / SSE.
- `INSTALL.bat` (rewrite) — single-click installer that on first run prompts ONLY 3 questions: backend domain, Let's Encrypt email, Namecheap DDNS password (skippable). Generates strong random JWT/admin/postback secrets via PowerShell `Membership.GeneratePassword`. Auto-writes `.env`, `ddns-config/config.json`, builds + starts the stack with the right `--profile`. Detects Docker / port 80 conflict / public IP. Final summary prints admin creds + 3 manual steps (Huawei port forward, Namecheap A record, Vercel deploy).
- `ddns-config/config.json.example` — Namecheap DDNS template.
- `.gitignore` — added `ddns-config/config.json` and `backend/secrets/` (with `.gitkeep`).
- `README.md`, `VERCEL-DEPLOY-GUIDE.md` — rewritten end-to-end Hindi/Urdu walk-through.
- `HOME-PC-SETUP-NO-CLOUDFLARE.md` — kept as the "manual deep-dive" version.
- Caddy `depends_on: ddns-updater (required:false)` — ensures DDNS pushes IP to Namecheap BEFORE Caddy attempts ACME challenge (avoids first-boot SSL issuance failure when running with DDNS profile).
- Restored `origin` git remote (`https://github.com/lenovogen03/lenovo-realflow.git`).

Testing iter_5: **50/50 PASS** (15 new + 17 iter_4 rebrand + 18 iter_3 clone-smoke regression). Zero regressions. Pre-existing minor findings unchanged (`/health` on root not `/api`, admin JWT vs CPI routes).

User flow:
1. Download repo ZIP → extract → `INSTALL.bat` double-click → 3 questions → 5-10 min build → backend ready.
2. Manual: Huawei port forward + Namecheap A record + Vercel deploy (3 steps, ~10 min total).
3. Done — `https://lenovo-realflow.vercel.app` accessible from anywhere.

### Session 3 (2026-01) — One-Click Self-Hosted Install (no Vercel/Cloudflare)

User clarified: **wants 100% self-hosted on home PC, NO Cloudflare, NO Vercel, NO ngrok**. Maximum speed via local network. Internet access only for RUT visits going out (Chromium → offer sites).

Final architecture:
```
Browser → http://localhost:80 (frontend container, nginx)
   ├── React app (static files)
   └── /api/* → backend container (internal Docker network)
                 └── mongo container (internal)
```

Files added/updated:
- `INSTALL.bat` — one-click installer: Docker check → port 80 conflict detect (auto-falls-back to 8080) → auto-generated `.env` with strong random secrets → `docker compose -p realtraffic up -d --build` → health check → prints admin creds + URLs.
- `UNINSTALL.bat` — clean wipe of realtraffic-only containers + volumes.
- `docker-compose.yml` — added `frontend` service (multi-stage React + nginx build with `REACT_APP_BACKEND_URL=""` so React calls relative `/api/*` → nginx proxies). Backend port no longer exposed externally (only via nginx). All containers/volumes/network `realtraffic-*` prefixed with `mem_limit` caps for the 16 GB host.
- `.env.example` — reference template (TUNNEL_TOKEN explicitly empty per user preference).
- `README.md` — 3-step Hindi/Urdu quickstart for self-host.
- `HOME-PC-SETUP-NO-CLOUDFLARE.md` — detailed Phase-2 guide (Huawei port forward + Namecheap DDNS + Nginx Proxy Manager + Let's Encrypt) for when public-internet access is needed.
- `docs/optional/VERCEL-DEPLOY-GUIDE.md` — moved here (kept for reference, not the chosen path).
- Patched all helper `.bat` scripts (`REALTRAFFIC-UPDATE.bat`, `REALTRAFFIC-STOP.bat`, `REALTRAFFIC-LOGS.bat`) to use `docker compose -p realtraffic` consistently.

User flow: GitHub → ZIP → extract → `INSTALL.bat` double-click → 5-10 min → `http://localhost` → done. LAN access from phones/laptops on same WiFi via `http://<pc-ip>`.

## Session 2 (2026-01) — Speed + Rebrand + Docker Isolation
- **Full rebrand**: 338 references `RealFlow → RealTraffic`, `realflow → realtraffic`, `REALFLOW → REALTRAFFIC` across 50+ files, plus package dir `realflow_cpi_worker → realtraffic_cpi_worker`, all `.bat`/`.ps1` scripts, HTML title, email defaults, DB name. Zero leftovers.
- **Backend speed fixes** in `real_user_traffic.py`:
  - Per-proxy geo-probe cache (15 min TTL) — same proxy on 2nd visit costs 0 s instead of 1-5 s.
  - Probe retries 3 → 2, backoff 1.5/3 s → 1 s, timeout 30 s → 12 s.
  - `networkidle` after goto: 20 s → 8 s.
  - Follow-redirect extra wait: 10 s → 5 s.
  - Thank-you pre-shot: 12 s → 6 s; content poll 8×1 s → 4×0.5 s; final sleep 1.2 s → 0.5 s.
  - Pre-submit screenshots switched to `full_page=False` (~3-5× faster).
  - Post-goto fixed sleep: 600-1100 ms → 200-400 ms.
- **Fast Mode (new, opt-in)**: Blocks images/fonts/media/analytics/trackers on landing pages. Thank-you page auto-unblocks so proof screenshot stays intact. Saves 30-70% per-visit time + ~40% Chromium RAM. Recommended for 16 GB PCs.
- **Concurrency cap 20 → 15** (backend enforced; UI max 15; default 8). Protects 16 GB RAM from swap thrashing.
- **Default `post_submit_wait` 6 s → 3 s.**
- **New `docker-compose.yml`**:
  - `name: realtraffic` (v2 project name) → all containers + network + volumes + ports isolated.
  - Container names: `realtraffic-mongo`, `realtraffic-backend`, `realtraffic-cloudflared`.
  - External port `8002` (was 8001) — avoids clash with existing Docker project.
  - All volumes prefixed `realtraffic-*`.
  - `mem_limit: 4g` on backend, `mem_limit: 1g` on mongo.
- **Admin credentials**: `admin@realtraffic.local` / `admin123` (env-seeded).
- **Frontend**: new Fast Mode toggle on RUT page with helper text; concurrency input max 15 with hardware-safety hint; improved error message (removed Cloudflare-specific wording).
- **Home-PC self-host guide** prepared at `/app/HOME-PC-SETUP-NO-CLOUDFLARE.md` (Huawei port forward + Namecheap DDNS + Nginx Proxy Manager + Let's Encrypt) — ready to use when user decides to drop Cloudflare.
- **Testing (iter_4): 35/35 PASS** (17 new rebrand assertions + 18 regression smoke), zero critical.

## Known minor pre-existing issues (non-blocking)
- `/health` on root `app` (not `api_router`) → not externally reachable. Internal probe OK.
- `/api/form-filler/jobs` returns `{"jobs": [...]}` while others return bare arrays.
- Admin JWT fails on CPI routes because admin is env-only (not in users collection).
- passlib/bcrypt version skew emits harmless traceback on every hash op.
- `server.py` ~12 k lines — router split overdue.

## Backlog / Next Action Items
- **P0 (done)**: All speed + rebrand + Docker isolation complete, tested green.
- **P1 (user)**: Free up home-PC RAM before big jobs (14.4 GB used / 1.5 GB free is the real current bottleneck). Ideally add second 16 GB DIMM to empty slot → 32 GB.
- **P1 (user)**: Migrate to self-hosting per `HOME-PC-SETUP-NO-CLOUDFLARE.md` when ready (removes 100 s tunnel timeout forever).
- **P2**: Move `/health` to `/api/health`. Pin `bcrypt<4.1`. Normalize form-filler list shape. Auto-provision admin row for CPI routes. Split `server.py` into routers.
- **P2**: Potential future: switch job-creation endpoint to fully async (return `job_id` within 1 s, do gsheet/excel parse in background task with status=preparing).

## Git
- Remote `origin` = `https://github.com/lenovogen03/lenovo-realflow.git`
- Branch = `main`
- Push via Emergent "Save to GitHub" feature.
- Note: repo name on GitHub still reads `lenovo-realflow`; user may want to rename the remote repo to `lenovo-realtraffic` via Namecheap/GitHub web UI at some point — local rebrand is complete.

---

### Session 6 (2026-01-XX) — Fresh Clone into Emergent Preview by Collaborator
- New collaborator cloned `https://github.com/janenstpetersons122-ctrl/realtraffic.git` into `/app` (preserved platform `.git` + `.emergent`).
- Recreated `backend/.env` (MONGO_URL, DB_NAME, JWT_SECRET_KEY, POSTBACK_TOKEN, ADMIN_EMAIL=admin@realtraffic.local, ADMIN_PASSWORD=admin123, APP_URL/PUBLIC_BASE_URL, SMTP/RESEND placeholders, GOOGLE_* placeholders).
- Recreated `frontend/.env` (REACT_APP_BACKEND_URL = preview URL, WDS_SOCKET_PORT=443).
- `pip install -r requirements.txt` → all backend deps installed (FastAPI 0.115.6, motor 3.6, playwright 1.49.1, selenium 4.43, openai 1.99.9, google-genai 1.71, stripe 15.0.1, resend 2.5.1, etc.).
- `yarn install` → frontend deps installed (React 18, CRA + craco, Radix UI, recharts, react-router 7).
- `playwright install chromium` → headless shell downloaded to `/pw-browsers/chromium_headless_shell-1148`.
- `supervisorctl restart backend frontend` → both RUNNING; mongodb auto-running.
- Smoke verified:
  - Backend `/health`: `mongo_connected: true`, admin email loaded from env.
  - `POST /api/admin/login` → returns valid JWT (`is_admin: true`).
  - `POST /api/auth/register` → user created with `status: pending`.
  - Frontend `RealTraffic` login UI renders correctly (dark theme, Login/Register/Admin Login/Forgot Password links).
- Test credentials saved to `/app/memory/test_credentials.md`.
- **Save flow**: Collaborator will use Emergent's "Save to GitHub" feature to push to `main` branch of the same repo.

