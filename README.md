# RealTraffic — Full Home-PC Deploy (Zero External Services)

> **Frontend + Backend + Database + SSL** — sab aapke PC pe Docker mein.
> Bahir se sirf **DuckDNS** (free DNS pointer, 30-sec signup) — taki kahin se bhi access ho.
> **Cost**: ₹0 / month

---

## ⚡ Quick Start (4 Steps, ~20 Min)

### 1️⃣ DuckDNS Account (30 sec, FREE)

1. https://www.duckdns.org
2. "Sign in with GitHub"
3. Top me `domain` field → apna unique name (e.g. `myrealtraffic`) → **"add domain"**
4. Top pe `token` (long string) — copy karke rakho

Aapka URL ban gaya: `myrealtraffic.duckdns.org`

### 2️⃣ Repo Download / Update

```cmd
git clone https://github.com/<owner>/realtraffic.git
cd realtraffic
```
Ya agar pehle se clone hai: `git pull`

### 3️⃣ `INSTALL.bat` pe DOUBLE-CLICK 🖱️

3 cheezein puchega:
1. DuckDNS subdomain (e.g. `myrealtraffic`)
2. DuckDNS token
3. Email (Let's Encrypt SSL renewal)

~10-15 min build (pehli baar) → sab 6 Docker containers start → admin password print.

### 4️⃣ Huawei Router Me Port 80 + 443 Forward (5 min, one-time)

`http://192.168.100.1` → Forward Rules → Port Mapping → Add:
- `WAN 80 → Local-IP 80  TCP`
- `WAN 443 → Local-IP 443  TCP`
- Save + Restart

5-10 min wait. Browser me kholo `https://yourname.duckdns.org` → App open ✅

---

## 📋 Login

- **URL**: `https://yourname.duckdns.org`
- **User**: `/login` → register → admin approve
- **Admin**: `/admin` → `admin@realtraffic.local` + password (INSTALL.bat ne print kiya tha)

**Password bhool gaye?** → `ONE-CLICK-ADMIN-RESET.bat` chalao.

---

## 📦 Aapke PC Pe Kya Chal Raha Hai

| Container | Role |
|---|---|
| `realtraffic-caddy` | Reverse proxy + auto Let's Encrypt SSL + rate-limit (port 80/443) |
| `realtraffic-frontend` | nginx serving React production build |
| `realtraffic-backend` | FastAPI (4 uvicorn workers) + Playwright |
| `realtraffic-mongo` | Database |
| `realtraffic-redis` | Cache layer |
| `realtraffic-ddns` | DuckDNS IP auto-update (every 5 min) |

**Sab `realtraffic-*` prefixed** → aapke PC pe pehle se chal rahe dusre Docker projects se clash nahi hoga.

---

## 🛠️ Roz Ke Commands

```cmd
REALTRAFFIC-LOGS.bat          (backend live logs)
REALTRAFFIC-STOP.bat          (sab stop)
RealTraffic-AUTO.bat          (git pull + rebuild + restart)
REALTRAFFIC-DOCTOR.bat        (health diagnose)
ONE-CLICK-ADMIN-RESET.bat     (admin password reset)
UNINSTALL.bat                 (⚠️ saara data wipe)
```

---

## 🆘 Common Issues

### "Docker not running"
Docker Desktop start karo, green "Running" dekho.

### "Build failed" (memory)
Docker Desktop → Settings → Resources → Memory **6 GB+** → Apply → INSTALL.bat retry.

### `https://...duckdns.org` nahi khul raha
1. **5-15 min wait** (first-time SSL issue ka time)
2. `docker logs realtraffic-caddy` — `certificate obtained` dikhna chahiye
3. Port forward verify: https://www.yougetsignal.com/tools/open-ports/ → 443 check
4. `docker logs realtraffic-ddns` — `successful update` dikhna chahiye

### Port 80 / 443 pehle se use me
`docker ps` — kaunsa container bind kiye hai. `docker stop <name>` ya alag port pe shift karo.

### RUT job slow hai
- Task Manager → 5+ GB RAM free karo
- RUT page me **⚡ Fast Mode** ON karo
- Concurrency 3-8 sweet spot (16 GB RAM PC)

---

## 🎯 Pro Tips

- **Fast Mode** ON = 40% kam RAM, 3-5x speed
- 16 GB → 32 GB RAM upgrade pe `.env` me `UVICORN_WORKERS=8` + `HEAVY_JOB_CONCURRENCY=16`
- Bade jobs se pehle Chrome / OneDrive close karo
- `.env` me `SENTRY_DSN=...` paste karke crash tracking enable karo (free tier 5k errors/month)

---

## 📚 Detailed Docs

- **`DEPLOY-NOW.md`** — step-by-step deploy walkthrough (Roman Urdu)
- **`PERFORMANCE-HARDENING.md`** — rate-limit, tuning, Sentry setup
- **`REALTRAFFIC-USER-GUIDE.md`** — feature usage guide

---

## 📞 Help

Koi step pe stuck ho jayein → error screenshot / logs share karein (`docker logs realtraffic-backend --tail 100 > log.txt`), fix bata dunga.
