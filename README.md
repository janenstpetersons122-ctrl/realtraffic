# RealTraffic — Easy Setup (No Custom Domain Needed)

> **Frontend** → Vercel free domain (`xxx.vercel.app`)
> **Backend**  → Aapka home PC (free DuckDNS + free Let's Encrypt SSL)
> **Cost**     → ₹0 / month

---

## 🎯 Aapko Bas 4 Cheezein Karni Hain

### 1️⃣ DuckDNS account banao (30 sec, FREE)

1. Open: **https://www.duckdns.org**
2. **"Sign in with GitHub"** ya Google se sign in
3. Top par "domains" field me apna unique naam daalo (jaise `myrealtraffic`)
4. **"add domain"** press karo
5. Top me **"token"** dikhayi dega — ek long string (e.g. `1a2b3c4d-...`) — copy karke rakhein

✅ Done — aapka URL ban gaya: `myrealtraffic.duckdns.org`

### 2️⃣ Repo download + INSTALL.bat chalao (~10 min)

1. GitHub par repo ke "Code" green button → **Download ZIP**
2. Extract karo (jaise `F:\online\RealTraffic`)
3. Folder me jao → **`INSTALL.bat` pe DOUBLE-CLICK**
4. 3 cheez puchega:
   - **DuckDNS subdomain**: `myrealtraffic` (jo aapne step 1 me banaya)
   - **DuckDNS token**: jo step 1 me copy kiya tha
   - **Email**: aapka email
5. 5-10 min wait (Docker images build hote hain pehli baar)
6. Final me admin password print hoga — **save karo!**

### 3️⃣ Huawei Router me Port Forward (5 min, one-time)

INSTALL.bat ne **aapka Local IP** print kiya tha (e.g. `192.168.100.50`). Ab:

1. Browser me: **`http://192.168.100.1`** (Nayatel default)
2. Login (sticker pe `admin/admin`)
3. **Forward Rules → Port Mapping → Add**:

| Rule | WAN Port | LAN IP | LAN Port | Protocol |
|---|---|---|---|---|
| HTTP | `80` | aapka local IP | `80` | TCP |
| HTTPS | `443` | aapka local IP | `443` | TCP |

4. Save + Reboot router
5. 5-10 min baad browser me kholke test karo: `https://myrealtraffic.duckdns.org/health`
6. Aana chahiye: `{"status":"ok"}`

### 4️⃣ Vercel pe Frontend Deploy (5 min, one-time)

1. **https://vercel.com/signup** → **"Continue with GitHub"**
2. **"Add New" → "Project"** → import **lenovo-realflow** repo
3. Settings exactly aise daalein:

| Setting | Value |
|---|---|
| Framework Preset | `Create React App` |
| **Root Directory** | `frontend` ⚠️ **bahut zaroori** |
| Build Command | `yarn build` |
| Output Directory | `build` |

4. **"Environment Variables"** expand karke ye 3 add karein:

| Name | Value |
|---|---|
| `REACT_APP_BACKEND_URL` | `https://myrealtraffic.duckdns.org` (apna URL) |
| `WDS_SOCKET_PORT` | `443` |
| `CI` | `false` |

5. **"Deploy"** press karo → 3-5 min wait
6. Production URL milega: `https://lenovo-realflow.vercel.app` (ya kuch similar)

✅ **Done. Aap aur aapke users wahan se login kar sakte hain.**

---

## 🔐 Login

- **URL**: Aapki Vercel URL (jaise `https://lenovo-realflow.vercel.app`)
- **Email**: `admin@realtraffic.local`
- **Password**: `.env` file me jo `ADMIN_PASSWORD=` ke baad likha hai

---

## 📦 Aapke Home PC pe Kya Chal Raha Hai

| Container | Kaam |
|---|---|
| `realtraffic-backend` | FastAPI + Playwright (RUT engine) |
| `realtraffic-mongo` | Database |
| `realtraffic-caddy` | Auto-SSL via Let's Encrypt |
| `realtraffic-ddns` | DuckDNS auto-update (har 5 min IP sync) |

---

## 🛠️ Roz Ke Commands

```cmd
REALTRAFFIC-LOGS.bat       (live backend logs)
REALTRAFFIC-STOP.bat       (sab stop)
REALTRAFFIC-UPDATE.bat     (GitHub se pull + rebuild)
UNINSTALL.bat              (saara data wipe — careful!)
```

---

## 🆘 Common Issues

### "Docker not running"
Docker Desktop start karo (Start Menu se), green "Running" indicator dekho.

### "Build failed"
Docker Desktop → Settings → Resources → Memory → 4 GB+ → Apply

### `https://myrealtraffic.duckdns.org/health` work nahi kar raha
1. **Wait 10-15 min** — first time DuckDNS + Let's Encrypt setup
2. **Caddy logs**: `docker logs realtraffic-caddy` — "obtained certificate" dikhna chahiye
3. **Port forward**: yougetsignal.com pe port 443 test karo
4. **DuckDNS logs**: `docker logs realtraffic-ddns` — successful update dikhna chahiye

### Vercel deploy "Module not found"
Root Directory `frontend` set kiya tha? Vercel → Project Settings → General → Root Directory → set to `frontend` → Redeploy.

### Browser "Failed to fetch" / "Network error"
Vercel pe `REACT_APP_BACKEND_URL` correct hai? `https://myrealtraffic.duckdns.org` exactly. Save → Redeploy.

### RUT job slow
- Task Manager → 5+ GB RAM free karo (Chrome/OneDrive close)
- RUT page me **⚡ Fast Mode** ON karo
- Concurrency 8 se zyada na rakho

---

## 🎯 Pro Tips

- ⚡ **Fast Mode** = 40% kam RAM, 3-5x speed
- Concurrency 3-8 sweet spot (16 GB RAM PC)
- Bade jobs se pehle 5+ GB RAM free
- Motherboard me ek slot khali (Task Manager check) → 16 GB DIMM add → 32 GB total → concurrency 15 safely

---

## 📞 Help

Koi step me masla aaye → screenshot bhej do → exact fix dunga.
