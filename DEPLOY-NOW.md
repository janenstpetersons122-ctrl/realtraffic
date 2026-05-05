# 🚀 RealTraffic — Deployment (Aapke Liye Step-by-Step)

> **Aapke pass already hai**: Vercel account ✅, GitHub repo ✅, ye codebase ✅
> **Aapko karna hai**: Sirf 4 steps — total ~20 min (build time + click-click)

---

## 📋 Pre-requisites Check (1 min)

✅ **Docker Desktop** install hai? Nahi to: https://www.docker.com/products/docker-desktop/
- Install ke baad Start Menu se Docker Desktop kholo, **green "Running" indicator** ka wait karo.

✅ **DuckDNS account** hai? (Free, 30 sec)
- https://www.duckdns.org → "Sign in with GitHub"
- Top mein domain field mein apna unique naam type karo (jaise `myrealtraffic`) → **"add domain"**
- Top mein **"token"** dikhega (long string) — copy karke kahin save kar lo

> ⚠️ Agar aapne pehle se domain banaya hua hai (jaise `realtraffic.online`), to step 2 ka shortcut bhi available hai — niche batayega.

---

## 🎯 STEP 1 — Repo Latest Pull Karo (2 min)

Aapke PC pe jahan code clone hai (jaise `F:\online\RealTraffic`):

```cmd
cd /d F:\online\RealTraffic
git fetch origin
git reset --hard origin/main
```

Ye latest code (with all hardening — 4 workers, rate limit, Redis, Sentry, etc.) le aayega.

---

## 🎯 STEP 2 — `INSTALL.bat` Pe DOUBLE-CLICK 🖱️ (10-15 min)

> **Bas yahi ek file** — jo aapne maanga tha. Ye sab kuch karega automatically.

`INSTALL.bat` aapse **3 cheezein puchega**:

| Q | Kya daalna hai | Example |
|---|---|---|
| 1 | DuckDNS subdomain | `myrealtraffic` |
| 2 | DuckDNS token | `1a2b3c4d-5e6f-...` |
| 3 | Email (SSL renewal alerts) | `you@example.com` |

Phir background mein automatic ye hoga:
1. Strong random JWT + admin password generate karega ✅
2. `.env` file likh dega (saare tuning vars: `UVICORN_WORKERS=4`, `HEAVY_JOB_CONCURRENCY=8`, etc.) ✅
3. `ddns-config/config.json` likh dega ✅
4. **Custom Caddy build karega** (with rate-limit plugin, ~3-5 min Go compile) ✅
5. **Backend image build karega** (Playwright + Python deps, ~5-7 min) ✅
6. **Saare 5 containers start karega**: mongo + redis + backend + caddy + ddns ✅
7. Backend health check ka wait karega ✅

**Final mein print hoga:**
```
✅ INSTALL COMPLETE

📦 Containers running:
    realtraffic-mongo      Up
    realtraffic-redis      Up
    realtraffic-backend    Up (healthy)
    realtraffic-caddy      Up
    realtraffic-ddns       Up

🌍 Aapki IPs:
     Public IP:  103.224.xxx.xxx        ← yeh note kar lo
     Local IP:   192.168.100.50          ← yeh note kar lo

🎯 Backend public URL:
     https://myrealtraffic.duckdns.org    ← Vercel mein yahi daalna hai

🔐 Admin Login:
     Email:    admin@realtraffic.local
     Password: [auto-generated 20-char password]   ← yeh SAVE karo!
```

> ⚠️ **Admin password ko safe jagah save karein** (password manager / WhatsApp self-chat). Reset script bhi available hai (`ONE-CLICK-ADMIN-RESET.bat`) agar bhul jayein.

---

## 🎯 STEP 3 — Huawei Router Port Forward (5 min, ONE TIME ONLY)

Backend ko internet se accessible banane ke liye:

1. Browser mein kholo: **http://192.168.100.1** (Nayatel default)
2. Login (router sticker pe likha hai — usually `admin / admin` ya `vodafone`)
3. **Forward Rules → Port Mapping → Add Rule**:

| Rule Name | Protocol | WAN Port | LAN IP (Step 2 wala) | LAN Port |
|---|---|---|---|---|
| HTTP | TCP | `80` | `192.168.100.50` | `80` |
| HTTPS | TCP | `443` | `192.168.100.50` | `443` |

4. **Save** → Router **restart**
5. **5-10 min wait** karo (DuckDNS IP propagate + Caddy ko Let's Encrypt SSL milne ka time)
6. **Test**: Browser mein `https://myrealtraffic.duckdns.org/health` kholo
   - Aana chahiye: `{"status":"ok","mongo_connected":true}` ✅
   - Agar nahi aaya: 5 min aur wait karo, ya `docker logs realtraffic-caddy` check karo (`certificate obtained` dikhna chahiye)

---

## 🎯 STEP 4 — Vercel Pe Frontend Deploy (5 min, ONE TIME ONLY)

Aapka Vercel account already hai. Ab:

1. **https://vercel.com/new** kholo
2. **"Import Git Repository"** → apni `realtraffic` repo select karo (agar pehli baar to GitHub authorize karna hoga)
3. Project settings **EXACTLY aise** daalein (most important hai!):

| Setting | Value |
|---|---|
| Framework Preset | `Create React App` |
| **Root Directory** | **`frontend`** ⚠️ (default `./` na chhodna!) |
| Build Command | `yarn build` |
| Output Directory | `build` |
| Install Command | `yarn install` |

4. **"Environment Variables"** expand karo, ye **3 add karo**:

| Name | Value |
|---|---|
| `REACT_APP_BACKEND_URL` | `https://myrealtraffic.duckdns.org` (Step 2 wala URL) |
| `WDS_SOCKET_PORT` | `443` |
| `CI` | `false` |

5. **"Deploy"** press karo → 3-5 min wait karo

6. **Production URL milega**: `https://realtraffic-xxx.vercel.app`
   - Yahi aap aur aapke users ko share karna hai
   - Kahin se bhi (mobile / kisi ka PC / cafe wifi) — login kar sakte ho

---

## 🎉 BAS! Aap Production-Ready Ho

### Login Test:
- **URL**: `https://realtraffic-xxx.vercel.app`
- **Admin tab pe click** → Email: `admin@realtraffic.local` / Password: (Step 2 wala)
- Login successful → Admin Dashboard kholega

---

## 📊 Daily Operations (Roz Ke Commands)

`F:\online\RealTraffic` folder mein se DOUBLE-CLICK:

| File | Kaam |
|---|---|
| `REALTRAFFIC-LOGS.bat` | Live backend logs dekho |
| `REALTRAFFIC-STOP.bat` | Sab stop |
| `RealTraffic-AUTO.bat` | GitHub se latest pull + auto rebuild + restart |
| `REALTRAFFIC-UPDATE.bat` | Manual update + rebuild |
| `REALTRAFFIC-DOCTOR.bat` | Health diagnose |
| `ONE-CLICK-ADMIN-RESET.bat` | Admin password bhul gaye to reset |
| `UNINSTALL.bat` | ⚠️ Saara data wipe (careful!) |

---

## 🛠️ Code Update Karne Ke Baad (Future Mein)

Jab aap (ya main) code change karein aur `main` branch pe push ho:

```cmd
cd /d F:\online\RealTraffic
RealTraffic-AUTO.bat
```

Ye automatically:
- `git pull` karega
- Backend container rebuild karega (Caddy/Mongo/Redis touch nahi karega — speed)
- Restart karega
- Health check karega

**Vercel ka frontend automatic update hota hai** har push pe — kuch karna nahi.

---

## 🆘 Common Problems & Fixes

### ❌ "Docker not running"
→ Docker Desktop start karo, green "Running" indicator dekho.

### ❌ Build failed (out of memory)
→ Docker Desktop → Settings → Resources → **Memory: 6 GB+** → Apply.

### ❌ `https://...duckdns.org/health` work nahi
1. **5-10 min wait** (pehli baar SSL issue mein time lagta hai)
2. `docker logs realtraffic-caddy` — `obtained certificate` dikhna chahiye
3. **Port forward verify** karo: https://www.yougetsignal.com/tools/open-ports/ → 443 enter → check
4. `docker logs realtraffic-ddns` — `successful update` dikhna chahiye

### ❌ Vercel pe deploy "Module not found"
→ Vercel Project → Settings → General → **Root Directory `frontend`** set kiya hai? Save → Redeploy.

### ❌ Browser mein "Failed to fetch" / "Network error"
→ Vercel project → Settings → Environment Variables → `REACT_APP_BACKEND_URL` exactly `https://yourname.duckdns.org` ho (no trailing slash). Save → Redeploy.

### ❌ "429 Too Many Requests" (legit user ko)
→ `Caddyfile` mein global zone `events 600` ko `1200` kar do → `docker compose restart caddy`.

### ❌ Backend OOM kill
→ `.env` mein `HEAVY_JOB_CONCURRENCY=8` ko `4` kar do → `docker compose restart backend`.

---

## 🎯 Performance Tuning (Optional — agar zaroorat ho)

`.env` file edit karke ye change kar sakte ho (phir `docker compose restart backend`):

| Variable | Default | 32 GB PC | Heavy Traffic | Effect |
|---|---|---|---|---|
| `UVICORN_WORKERS` | 4 | 8 | 8 | Concurrent request capacity |
| `HEAVY_JOB_CONCURRENCY` | 8 | 16 | 12 | Per-worker heavy ops max |
| `MONGO_MAX_POOL_SIZE` | 150 | 250 | 200 | DB connection pool |

**Sentry enable karna hai?** (free tier 5000 errors/month):
1. https://sentry.io/signup/ → New Project → Python → FastAPI → DSN copy
2. `.env` mein `SENTRY_DSN=https://xxx@oxxx.ingest.sentry.io/xxx` paste
3. `docker compose restart backend`
4. Sentry dashboard pe live errors / slow endpoints dikhenge

---

## 📞 Help

Koi step me masla aaye → exact error message ya screenshot share karo, main fix bata dunga.

**Specifically jo logs share karne kaam aate hain:**
```cmd
docker logs realtraffic-backend --tail 100 > backend-log.txt
docker logs realtraffic-caddy --tail 50 > caddy-log.txt
```

In files ko WhatsApp pe bhej do.

---

## 🎁 Summary — Aapne Kya Achieve Kiya

✅ **Frontend on Vercel**: `https://realtraffic-xxx.vercel.app` — kahin se bhi accessible
✅ **Backend on home PC**: 4 uvicorn workers, 32 concurrent heavy jobs, auto-restart on crash
✅ **Auto SSL**: Let's Encrypt cert auto-renewed forever, FREE
✅ **Rate limiting**: DDoS / brute-force protection at the edge
✅ **DDNS**: IP rotate ho to bhi DNS automatic update
✅ **Monitoring ready**: Sentry DSN add karte hi crash tracking ON
✅ **Cost**: ₹0 / month — sirf bijli aur internet

🚀 **Start karo!**
