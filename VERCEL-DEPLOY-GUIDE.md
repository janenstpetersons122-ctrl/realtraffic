# 🚀 Vercel Frontend Deploy — RealTraffic

> Frontend Vercel pe deploy karne ki step-by-step guide. Backend home PC pe `INSTALL.bat` se already setup ho chuka hai.

---

## ✅ Pehle Confirm Karo

INSTALL.bat ke baad ye sab kaam kar raha hai?

- [ ] `https://api.yourdomain.com/health` browser me kholo → `{"status":"ok"}` aana chahiye
- [ ] Agar nahi aata to: Huawei port forward done? Namecheap A record done? Caddy logs (`docker logs realtraffic-caddy`) me "obtained certificate" dikha?

Yes? Toh chalo Vercel pe deploy karte hain.

---

## 📦 Phase 1 — Vercel Sign Up (1 min)

1. Open https://vercel.com/signup
2. **"Continue with GitHub"** click karo
3. GitHub login → access grant karo Vercel ko

---

## 🔌 Phase 2 — Repo Import (2 min)

1. Vercel dashboard → top-right **"Add New..." → Project**
2. **"Import Git Repository"** me aapka repo dikhega: `lenovogen03/lenovo-realflow`
   - Nahi dikh raha? **"Adjust GitHub App Permissions"** → repo access do
3. Repo ke saamne **"Import"** button

---

## ⚙️ Phase 3 — Build Settings ⚠️ Important

Import screen pe ye exactly daalo:

| Setting | Value |
|---|---|
| **Framework Preset** | `Create React App` |
| **Root Directory** | `frontend` ⬅️ **THIS** |
| Build Command | `yarn build` |
| Output Directory | `build` |
| Install Command | `yarn install` |
| Node.js Version | `20.x` |

> "Root Directory" — Repo me frontend `/frontend` subfolder me hai, agar nahi set kiya to build fail hoga.

---

## 🔐 Phase 4 — Environment Variables

Same screen me **"Environment Variables"** expand karo. 3 variables add karo:

| Name | Value |
|---|---|
| `REACT_APP_BACKEND_URL` | `https://api.yourdomain.com` ⬅️ jo aapne INSTALL.bat me daala tha |
| `WDS_SOCKET_PORT` | `443` |
| `CI` | `false` |

Production, Preview, Development — sab tick rakhna.

---

## 🎯 Phase 5 — Deploy (3 min)

**"Deploy"** button press karo. Vercel ye karega:
1. Repo clone (~30 sec)
2. `cd frontend && yarn install` (~1 min)
3. `yarn build` (~2 min)
4. Deploy

Success milne pe production URL aayega: `https://lenovo-realflow.vercel.app` (ya kuch similar).

---

## ✅ Phase 6 — Test

1. Production URL kholo
2. **RealTraffic branding + login page** dikhni chahiye
3. **Login** karo: `admin@realtraffic.local` + `.env` me jo password hai
4. **Real User Traffic** page kholo
5. **⚡ Fast Mode** checkbox dikhna chahiye

Sab kaam kar raha? Subhanallah! Aap online ho. 🎉

---

## 🐛 Troubleshooting

### Build fails: "Module not found" / "Can't resolve"
- Root Directory `frontend` set hai? Settings → General → Root Directory check karo.
- `frontend/package.json` complete hai? Local me `cd frontend && yarn install` chala lo dekhne ke liye.

### Browser console: "Failed to fetch" / "Network error"
- F12 → Network tab → failed request ka URL dekho
- URL `localhost` hit kar raha hai? → `REACT_APP_BACKEND_URL` env var set nahi hua. Vercel → Settings → Environment Variables → check → Save → Redeploy.
- URL `https://api.yourdomain.com` hit kar raha hai but failing? → Backend public se reachable nahi. Backend `/health` browser me direct kholke check karo.

### "CORS policy" error
Backend `.env` me `CORS_ORIGINS=*` (default). Specific origin chahiye ho to:
```
CORS_ORIGINS=https://lenovo-realflow.vercel.app
```
Phir `docker compose -p realtraffic restart backend`.

### "Mixed content" warning
Frontend HTTPS pe hai, backend HTTP pe hain (no SSL). Caddy se SSL setup ho chuka hai? `https://api.yourdomain.com` browser me direct kholke confirm karo.

---

## 🎨 Custom Domain (Optional)

Free Vercel URL (`xxx.vercel.app`) ki jagah `realtraffic.online` use karna ho:

1. Vercel project → **Settings → Domains → Add**
2. `realtraffic.online` enter
3. Vercel 2 DNS records batayega (A record + CNAME)
4. Namecheap → Advanced DNS → wo records add karo (CNAME for `www`, A for root)
5. 5-30 min me propagate + auto SSL

> **Note**: Frontend ka `realtraffic.online` aur backend ka `api.realtraffic.online` — dono Namecheap se manage hote hain. Same domain, alag subdomains.

---

## 🔄 Auto-Deploy

Vercel default me ON karta hai: **har baar `main` branch pe push pe auto-redeploy**.

Aapka workflow:
1. Code change (Emergent ya local)
2. **"Save to GitHub"** chat me press karo
3. 2-3 min me Vercel auto-deploy
4. Production URL pe new version live

Manual kuch nahi karna.

---

## ✨ Final Architecture Visualization

```
┌─────────────────────────────────────────────┐
│  User Browser (anywhere in the world)       │
└─────────────────────────────────────────────┘
                      │
                      │ https://lenovo-realflow.vercel.app
                      ▼
┌─────────────────────────────────────────────┐
│  Vercel CDN (free, always-on)               │
│  serves React static files                  │
└─────────────────────────────────────────────┘
                      │
                      │ API call to https://api.yourdomain.com/api/...
                      ▼
┌─────────────────────────────────────────────┐
│  Namecheap DNS → Aapka public IP            │
└─────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────┐
│  Huawei Router (port 443 forwarded)         │
└─────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────┐
│  Aapka Home PC (Docker)                     │
│   ┌──────────────────────────────────┐      │
│   │  realtraffic-caddy (auto SSL)    │      │
│   │  realtraffic-backend (FastAPI)   │      │
│   │  realtraffic-mongo (DB)          │      │
│   │  realtraffic-ddns (auto-update)  │      │
│   └──────────────────────────────────┘      │
└─────────────────────────────────────────────┘
```

**Result**: Aap aur aapke users kahin se bhi `https://lenovo-realflow.vercel.app` se login kar sakte hain. Backend home PC pe chalega — fast, free, full control.
