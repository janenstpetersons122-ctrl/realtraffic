# ===============================================================
#   RealTraffic - Backend Dockerfile
#
#   Uses Microsoft's official Playwright Python image which already
#   has Chromium + all system dependencies pre-installed, so the
#   build is fast and reliable.
# ===============================================================
FROM mcr.microsoft.com/playwright/python:v1.49.1-noble

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_DEFAULT_TIMEOUT=600 \
    PIP_RETRIES=10 \
    DEBIAN_FRONTEND=noninteractive

# Install curl for healthchecks (everything else already there)
RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# ---- Python deps (cached layer) ----
# Main requirements (public PyPI only — never fails)
# Long timeout + many retries = robust against slow / flaky networks
COPY requirements.txt ./
RUN pip install --upgrade pip setuptools wheel \
        --timeout 600 --retries 10 \
    && grep -v "^emergentintegrations" requirements.txt > /tmp/req-core.txt \
    && pip install -r /tmp/req-core.txt \
        --timeout 600 --retries 10 \
        --index-url https://pypi.org/simple/ \
        --extra-index-url https://pypi.python.org/simple/

# Optional: emergentintegrations from Emergent's private CDN
# (used only by AI automation generator — wrapped in try/except in code,
# so build will NOT fail if CDN is unreachable)
RUN pip install emergentintegrations==0.1.0 \
        --timeout 300 --retries 5 \
        --extra-index-url https://d33sy5i8bnduwe.cloudfront.net/simple/ \
        || echo "WARN: emergentintegrations install skipped (AI features will gracefully degrade)"

# ---- Copy source ----
COPY . .

EXPOSE 8001

# Multi-worker uvicorn for higher concurrency under bulk RUT/CPI load.
# Default 4 workers; override via env $UVICORN_WORKERS in your platform.
ENV UVICORN_WORKERS=4
CMD ["sh", "-c", "uvicorn server:app --host 0.0.0.0 --port ${PORT:-8001} --workers ${UVICORN_WORKERS:-4} --timeout-keep-alive 30 --proxy-headers --forwarded-allow-ips '*'"]
