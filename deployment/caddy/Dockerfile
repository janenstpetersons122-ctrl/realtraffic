# ===============================================================
#   RealTraffic - Custom Caddy Build (with rate-limit plugin)
#
#   Builds Caddy with the official `mholt/caddy-ratelimit` module
#   so we can throttle abusive clients at the edge — DDoS / bot
#   storms get rejected BEFORE they touch the FastAPI backend.
# ===============================================================
FROM caddy:2-builder-alpine AS builder

RUN xcaddy build \
    --with github.com/mholt/caddy-ratelimit

FROM caddy:2-alpine

# Replace the default Caddy binary with the one we just built
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
