# 🏠 RealTraffic — Home PC Self-Hosting Guide (No Cloudflare)

Complete guide for running the backend on your home PC and serving it publicly **without Cloudflare**, using:
- Nayatel public IP (154.x.x.x — confirmed public, not CGNAT)
- Namecheap domain + Dynamic DNS
- Huawei router port forwarding
- Nginx Proxy Manager + Let's Encrypt free SSL
- Vercel for frontend (free subdomain OR your custom domain later)

> **Current state**: You're using Cloudflare Tunnel. This guide switches to direct self-hosting. You can follow it anytime — **no rush**. Your app already works via Cloudflare with the speed fixes applied.

---

## Phase 1 — Preparation (5 min)

### Get your PC's local IP

Open Command Prompt (as Admin) and run:
```cmd
ipconfig
```

Look for the active adapter (Ethernet usually) and note the `IPv4 Address`. Example: `192.168.1.50`. That's your **local IP**.

Keep this handy — you'll need it in Step 2.

---

## Phase 2 — Router Port Forwarding (5 min)

### Access Huawei router

1. Browser → `http://192.168.100.1` (Nayatel default) OR `http://192.168.1.1`
2. Login (sticker on router: usually `admin` / `admin` or printed password)

### Add port forward rules

Navigate: **Forward Rules** → **Port Mapping Configuration** → **Add**

| Rule Name | WAN Port | LAN IP | LAN Port | Protocol |
|---|---|---|---|---|
| RealTraffic-HTTP | 80 | `<your PC local IP>` | 80 | TCP |
| RealTraffic-HTTPS | 443 | `<your PC local IP>` | 443 | TCP |

**Save + Reboot router** (not always needed, but safest).

---

## Phase 3 — Windows Firewall (3 min)

Open PowerShell as Admin and run:
```powershell
New-NetFirewallRule -DisplayName "RealTraffic HTTP" -Direction Inbound -Protocol TCP -LocalPort 80 -Action Allow
New-NetFirewallRule -DisplayName "RealTraffic HTTPS" -Direction Inbound -Protocol TCP -LocalPort 443 -Action Allow
```

---

## Phase 4 — Namecheap DNS Setup (5 min)

### Add A-records pointing to your home public IP

1. Login to Namecheap → **Domain List** → pick your domain (e.g. `yourdomain.com`) → **Manage**
2. Go to **Advanced DNS**
3. Add Records:

| Type | Host | Value | TTL |
|---|---|---|---|
| A Record | `@` | Your public IP (e.g. `154.192.134.6`) | Automatic |
| A Record | `api` | Same public IP | Automatic |

### Enable Dynamic DNS (so IP changes are auto-tracked)

Still in **Advanced DNS** tab → scroll down → **Dynamic DNS** toggle **ON** → copy the **DDNS password** (looks like a long hex string).

Save this password — you'll paste it into the DDNS updater in Phase 6.

---

## Phase 5 — Nginx Proxy Manager (handles SSL + routing)

### Add to docker-compose.yml

Already prepared in `/app/docker-compose.yml`. Append the following services (I'll include them as a separate file you can merge):

Create `/app/docker-compose.nginx.yml`:
```yaml
name: realtraffic-edge

services:
  nginx-proxy-manager:
    image: jc21/nginx-proxy-manager:latest
    container_name: realtraffic-npm
    restart: unless-stopped
    ports:
      - "80:80"       # HTTP (Let's Encrypt challenges + redirects)
      - "443:443"     # HTTPS (public traffic)
      - "127.0.0.1:81:81"  # Admin UI (local-only for safety)
    volumes:
      - npm-data:/data
      - npm-letsencrypt:/etc/letsencrypt
    networks:
      - realtraffic-net
    depends_on:
      - backend

  ddns-updater:
    image: qmcgaw/ddns-updater:latest
    container_name: realtraffic-ddns
    restart: unless-stopped
    volumes:
      - ./ddns-config:/updater/data
    environment:
      - PERIOD=5m
    networks:
      - realtraffic-net

volumes:
  npm-data:
    name: realtraffic-npm-data
  npm-letsencrypt:
    name: realtraffic-npm-letsencrypt

networks:
  realtraffic-net:
    external: true
```

### Configure DDNS updater

Create `/app/ddns-config/config.json`:
```json
{
  "settings": [
    {
      "provider": "namecheap",
      "domain": "yourdomain.com",
      "host": "@",
      "password": "YOUR_NAMECHEAP_DDNS_PASSWORD"
    },
    {
      "provider": "namecheap",
      "domain": "yourdomain.com",
      "host": "api",
      "password": "YOUR_NAMECHEAP_DDNS_PASSWORD"
    }
  ]
}
```

Replace `yourdomain.com` and `YOUR_NAMECHEAP_DDNS_PASSWORD`.

### Launch everything

```powershell
cd F:\online\RealTraffic  # or wherever your repo is on home PC
docker compose -p realtraffic -f docker-compose.yml -f docker-compose.nginx.yml up -d
```

### First-time Nginx Proxy Manager setup

1. Open `http://localhost:81`
2. Default login: `admin@example.com` / `changeme`
3. **Change admin credentials** immediately
4. Go to **Hosts → Proxy Hosts → Add Proxy Host**:
   - Domain Names: `api.yourdomain.com`
   - Forward Hostname / IP: `backend` (Docker service name — resolves within the network)
   - Forward Port: `8001`
   - **SSL tab** → check "Request a new SSL Certificate" → "Force SSL" → "HTTP/2 Support" → check "I agree to Let's Encrypt TOS" → enter your email
   - Save

Within 30 seconds you should have `https://api.yourdomain.com` live with a valid Let's Encrypt cert.

---

## Phase 6 — Vercel Frontend Update (2 min)

### Update env var
1. Vercel dashboard → your frontend project → Settings → Environment Variables
2. `REACT_APP_BACKEND_URL` = `https://api.yourdomain.com`
3. Redeploy (Deployments tab → pick latest → ⋯ → Redeploy)

---

## Phase 7 — Remove Cloudflare (optional, after testing)

Once everything works on `https://api.yourdomain.com`:

```powershell
docker compose -p realtraffic stop cloudflared
docker compose -p realtraffic rm -f cloudflared
```

---

## Troubleshooting

### `api.yourdomain.com` → "DNS not found"
- DNS propagation can take 5-30 min first time. Check with: `nslookup api.yourdomain.com 8.8.8.8`
- Verify A record has correct IP in Namecheap Advanced DNS.

### "Connection refused" after port forwarding
- Router port rule pointing to wrong local IP? Re-verify with `ipconfig`.
- Windows Firewall blocking? Re-check the 2 rules added in Phase 3.
- ISP blocks inbound port 80? Rare but possible — test from mobile hotspot.

### Let's Encrypt cert fails
- Port 80 must be reachable from internet (LE uses HTTP-01 challenge).
- `docker logs realtraffic-npm` shows the exact error.

### IP changed and site is down
- DDNS updater runs every 5 min. Check logs: `docker logs realtraffic-ddns`
- Manually update A records in Namecheap if urgent.

---

## Quick Commands

```powershell
# See all realtraffic containers
docker ps --filter "name=realtraffic-"

# Logs
docker logs -f realtraffic-backend
docker logs -f realtraffic-npm
docker logs -f realtraffic-ddns

# Restart just backend after code pull
docker compose -p realtraffic restart backend

# Full stop
docker compose -p realtraffic down

# Nuke everything including data (⚠️ erases DB + uploads + screenshots)
docker compose -p realtraffic down -v
```

---

## Hardware Tips for 16 GB RAM PC

- Before starting a big RUT job, close Chrome / OneDrive / Discord to free RAM.
- Task Manager → Memory tab → aim for at least **6 GB free** before a big job.
- Stick to `concurrency ≤ 8` unless Fast Mode is ON (then up to 12 is safe).
- Fast Mode (checkbox on RUT page) saves ~40% RAM per visit — **recommended for your PC**.
- Adding a second 16 GB DIMM to your motherboard (Slot 2 is empty per Task Manager) → 32 GB total → concurrency 15 safely. Best upgrade for this project.
