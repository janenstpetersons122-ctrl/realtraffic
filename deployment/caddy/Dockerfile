# ===============================================================
#   RealTraffic - Custom Caddy Build
#   Plugins:
#     • mholt/caddy-ratelimit  → per-IP rate limiting at edge
#     • caddy-dns/duckdns       → DNS-01 ACME challenge (no port 80 needed)
# ===============================================================
FROM caddy:2-builder-alpine AS builder

RUN xcaddy build \
    --with github.com/mholt/caddy-ratelimit \
    --with github.com/caddy-dns/duckdns

FROM caddy:2-alpine

# Replace default Caddy binary with the rebuilt one (with plugins)
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
