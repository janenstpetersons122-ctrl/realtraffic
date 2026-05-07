# 🚀 RealTraffic — Deploy Guide (Full Home-PC, NO Vercel)

> **Architecture**: Sab kuch aapke PC pe (frontend + backend + DB + SSL). Bahir se sirf DuckDNS (free DNS pointer). Bas.

---

## ✅ Aapko Sirf Ye 4 Steps Karne Hain (~20 min)

### STEP 1 — DuckDNS Account Banao (30 sec)

1. https://www.duckdns.org kholo
2. **"Sign in with GitHub"** click karo (30 sec signup, no personal data)
3. Top me **"domain"** field me apna unique name daalo:
   - Example: `myrealtraffic` → URL banega `myrealtraffic.duckdns.org`
4. **"add domain"** button press karo
5. Top me **"token"** field ki long string copy karke kahin save kar lo
   - Jaise: `1a2b3c4d-5e6f-7g8h-9i0j-1k2l3m4n5o6p`

✅ Done.

---

### STEP 2 — Latest Code Pull Karo (2 min)

Apne PC pe jahan repo clone hai (jaise `F:\online\RealTraffic`), Command Prompt me:

```cmd
cd /d F:\online\RealTraffic
git pull
```

---

### STEP 3 — `INSTALL.bat` Pe DOUBLE-CLICK 🖱️ (10-15 min)

Bas yahi ek file. Ye **6 containers** automatically build + start karegi:

| Container | Kaam |
|---|---|
| `realtraffic-mongo` | Database |
| `realtraffic-redis` | Cache layer |
| `realtraffic-backend` | FastAPI (4 workers, Playwright, rate limiting, Sentry ready) |
| `realtraffic-frontend` | nginx — React production build |
| `realtraffic-caddy` | Reverse proxy + auto-SSL (Let's Encrypt) + rate limiting |
| `realtraffic-ddns` | DuckDNS auto-IP updater (every 5 min) |

Script aapse **3 cheezein** puchegi:

| Q | Answer | Example |
|---|---|---|
| 1 | DuckDNS subdomain (bina .duckdns.org) | `myrealtraffic` |
| 2 | DuckDNS token | `1a2b3c4d-5e6f-...` |
| 3 | Email (SSL renewal alerts) | `you@example.com` |

Phir automatic ye hoga:

1. ✅ Docker running check
2. ✅ Port 80/443 conflict check (purane docker projects safe)
3. ✅ Strong random JWT + admin password generate
4. ✅ `.env` likho (saare tuning vars)
5. ✅ `ddns-config/config.json` likho
6. ✅ **6 Docker images build** (~10-15 min pehli baar — backend Playwright install + frontend yarn build + custom Caddy Go compile)
7. ✅ **Sab containers start**
8. ✅ Health check wait

**Final output:**

```
✅ INSTALL COMPLETE

📦 Containers running:
    realtraffic-mongo       Up (healthy)
    realtraffic-redis       Up (healthy)
    realtraffic-backend     Up (healthy)
    realtraffic-frontend    Up (healthy)
    realtraffic-caddy       Up
    realtraffic-ddns        Up

🌍 Aapki IPs:
     Public IP:  103.224.xxx.xxx
     Local IP:   192.168.100.50

🎯 Aapka App URL:
     https://myrealtraffic.duckdns.org

🔐 Admin Login:
     Go to:    https://myrealtraffic.duckdns.org/admin
     Email:    admin@realtraffic.local
     Password: [20-char auto-generated]   ← SAVE IT!
```

---

### STEP 4 — Huawei Router Port Forward (5 min, ONE TIME)

Ye sirf ek baar karna hai — internet se aapke PC tak route banana.

1. Browser me kholo: **`http://192.168.100.1`** (Nayatel default)
2. Login (sticker pe likha — usually `admin/admin` ya `vodafone`)
3. **Forward Rules → Port Mapping → Add Rule**:

| Rule | WAN Port | LAN IP | LAN Port | Protocol |
|---|---|---|---|---|
| HTTP | `80` | `192.168.100.50` (Step 3 wala) | `80` | TCP |
| HTTPS | `443` | `192.168.100.50` | `443` | TCP |

4. **Save** → Router **restart**
5. **5-10 min wait** (DuckDNS IP propagate + Caddy ko Let's Encrypt SSL mil raha)
6. **Test**:
   - Browser me kholo: `https://myrealtraffic.duckdns.org`
   - **RealTraffic login page** dikhni chahiye ✅
   - Admin me login: `https://myrealtraffic.duckdns.org/admin`

---

## 🎉 BAS! Aap Production Live Ho

**Aapka app**: `https://myrealtraffic.duckdns.org`

- Frontend ✅ (React UI)
- Backend ✅ (FastAPI 4 workers)
- Database ✅ (MongoDB)
- SSL ✅ (Let's Encrypt auto-renewed)
- Rate limiting ✅
- Auto-restart on crash ✅
- DuckDNS auto-IP update ✅
- **Kahin se bhi access** — mobile, cafe wifi, anywhere

**Cost**: ₹0 / month (bas bijli + internet)

---

## 📊 Daily Operations

| File (folder me double-click) | Kaam |
|---|---|
| `REALTRAFFIC-LOGS.bat` | Live backend logs |
| `REALTRAFFIC-STOP.bat` | Sab stop |
| `RealTraffic-AUTO.bat` | Git pull + rebuild + restart |
| `REALTRAFFIC-UPDATE.bat` | Manual update |
| `REALTRAFFIC-DOCTOR.bat` | Health diagnose |
| `ONE-CLICK-ADMIN-RESET.bat` | Admin password bhul gaye to reset |
| `UNINSTALL.bat` | ⚠️ Saara data wipe |

---

## 🔧 Code Update (Future me)

Jab bhi main / aap code change karein aur GitHub pe push ho:

```cmd
cd /d F:\online\RealTraffic
RealTraffic-AUTO.bat
```

Ye automatic:
- `git pull`
- Backend + frontend rebuild
- Restart
- Health check

Sab 30 sec me ready.

---

## 🆘 Common Problems & Fixes

### ❌ "Docker not running"
→ Docker Desktop start karo, green "Running" indicator dekho.

### ❌ Port 80 / 443 already in use
→ INSTALL.bat khud detect karke bata dega. Purane Docker project ko `docker ps` se dekho, `docker stop <name>` se band karo. Ya us project ko alag port pe shift karo.

### ❌ Build failed (out of memory)
→ Docker Desktop → Settings → Resources → **Memory: 6 GB+** → Apply → `INSTALL.bat` dobara chalao.

### ❌ `https://...duckdns.org` work nahi
1. **5-10 min wait** (first-time SSL issue time leta hai)
2. Logs check: `docker logs realtraffic-caddy` — `obtained certificate` dikhna chahiye
3. Port forward verify: https://www.yougetsignal.com/tools/open-ports/ → port 443 → check
4. DuckDNS update: `docker logs realtraffic-ddns` — `successful update` dikhna chahiye

### ❌ Browser me "Failed to fetch" / "Network error"
→ `docker logs realtraffic-frontend` (nginx errors check karo)
→ `docker logs realtraffic-backend` (API errors check karo)

### ❌ "429 Too Many Requests" (legit user ko)
→ `Caddyfile` me `events 600` → `events 1200` → `docker compose restart caddy`

### ❌ Backend OOM kill
→ `.env` me `HEAVY_JOB_CONCURRENCY=8` → `4` → `docker compose restart backend`

---

## 🎯 Performance Tuning (Optional)

`.env` me edit karke phir `docker compose restart backend`:

| Variable | Default | 32 GB PC | Heavy Traffic |
|---|---|---|---|
| `UVICORN_WORKERS` | 4 | 8 | 8 |
| `HEAVY_JOB_CONCURRENCY` | 8 | 16 | 12 |
| `MONGO_MAX_POOL_SIZE` | 150 | 250 | 200 |

---

## 🛡️ Sentry Monitoring (Optional, FREE)

Production errors live track karne ke liye:

1. https://sentry.io/signup/ → Free account
2. New Project → **Python → FastAPI**
3. DSN copy (`https://xxx@oxxx.ingest.sentry.io/xxx`)
4. `.env` me paste: `SENTRY_DSN=https://...`
5. `docker compose restart backend`

Crashes, slow endpoints, error spikes — sab Sentry dashboard me dikhenge.

---

## 📋 Architecture Summary (Aap Ka Poora Stack)

```
┌──────────────────────────────────────────────────────────────┐
│  Browser (mobile / laptop / cafe wifi — kahin se)            │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         │  https://myrealtraffic.duckdns.org
                         │  (Let's Encrypt SSL, auto-renewed)
                         │
┌────────────────────────▼─────────────────────────────────────┐
│                    AAPKE PC PE DOCKER                        │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  realtraffic-caddy  (ports :80 + :443)              │    │
│  │  • Auto-SSL via Let's Encrypt                       │    │
│  │  • Rate limiting (auth 10/10s, global 600/60s)      │    │
│  │  • Reverse proxy:                                   │    │
│  │     /api/*, /health, /ws, /r, /t  → backend:8001    │    │
│  │     /*  (everything else)          → frontend:80    │    │
│  └──────────┬───────────────────────────────┬──────────┘    │
│             │                               │                │
│  ┌──────────▼────────────┐  ┌───────────────▼────────────┐  │
│  │  realtraffic-backend  │  │  realtraffic-frontend      │  │
│  │  FastAPI              │  │  nginx (React build)       │  │
│  │  4 uvicorn workers    │  │  Static files + SPA        │  │
│  │  Playwright           │  │                            │  │
│  └──────┬──────────┬─────┘  └────────────────────────────┘  │
│         │          │                                        │
│  ┌──────▼────┐ ┌───▼──────┐                                 │
│  │  mongo    │ │  redis   │    ┌──────────────────────┐     │
│  │  7        │ │  7       │    │  realtraffic-ddns    │     │
│  │  Database │ │  Cache   │    │  DuckDNS auto-update │     │
│  └───────────┘ └──────────┘    └──────────┬───────────┘     │
│                                           │                 │
└───────────────────────────────────────────┼─────────────────┘
                                            │
                                 ┌──────────▼──────────┐
                                 │  duckdns.org        │
                                 │  (only external     │
                                 │   — just DNS ptr)   │
                                 └─────────────────────┘
```

**External dependencies**: Sirf DuckDNS (free DNS pointer) + Let's Encrypt (free SSL). Aur kuch nahi.

---

## 🎁 Login Credentials

After install, INSTALL.bat final output me milega. Save kar lein:

- **URL**: `https://yourname.duckdns.org`
- **User login**: `/login` pe apna account banayein (register), phir admin approve karega
- **Admin login**: `/admin` pe → `admin@realtraffic.local` / (auto-generated password)

**Agar password bhul jayein**: `ONE-CLICK-ADMIN-RESET.bat` chalao — naya password generate ho jayega.

---

## 📞 Help

Kahin stuck ho jayein → error screenshot / logs share karein:

```cmd
docker logs realtraffic-backend --tail 100 > backend-log.txt
docker logs realtraffic-caddy --tail 50 > caddy-log.txt
docker logs realtraffic-frontend --tail 50 > frontend-log.txt
```

Files mujhe WhatsApp / chat pe bhej dein — fix bata dunga.

---

🚀 **Aap taiyar hain! DuckDNS signup → `git pull` → `INSTALL.bat` double-click → router port forward → DONE.**
