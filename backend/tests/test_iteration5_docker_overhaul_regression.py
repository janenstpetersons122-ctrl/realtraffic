"""
Iteration 5 regression smoke after docker-compose / Caddyfile / INSTALL.bat overhaul.
Per review_request: verify backend Python/runtime untouched. Skip Playwright.
Skip actually starting an RUT job. Hit listed endpoints + RUT validation guards.
"""

import os
import time
import uuid
import requests
import pytest

BASE_URL = os.environ.get(
    "REACT_APP_BACKEND_URL",
    "http://localhost:8001",
).rstrip("/")
# We test against the public ingress URL exactly as user-facing traffic would.
# But /health is on bare app (not /api) and only reachable internally — so we
# cover it via localhost.
INTERNAL = "http://localhost:8001"

ADMIN_EMAIL = "admin@realtraffic.local"
ADMIN_PASSWORD = "admin123"


@pytest.fixture(scope="module")
def s():
    sess = requests.Session()
    sess.headers.update({"Content-Type": "application/json"})
    return sess


@pytest.fixture(scope="module")
def admin_token(s):
    r = s.post(
        f"{BASE_URL}/api/admin/login",
        json={"email": ADMIN_EMAIL, "password": ADMIN_PASSWORD},
        timeout=15,
    )
    assert r.status_code == 200, f"admin login failed: {r.status_code} {r.text}"
    body = r.json()
    assert body.get("is_admin") is True
    assert isinstance(body.get("access_token"), str) and len(body["access_token"]) > 20
    return body["access_token"]


@pytest.fixture(scope="module")
def admin_headers(admin_token):
    return {"Authorization": f"Bearer {admin_token}", "Content-Type": "application/json"}


# ---------- Health ----------
def test_health_internal():
    # /health is on bare app (known iter_4 finding) -> probe localhost
    r = requests.get(f"{INTERNAL}/health", timeout=10)
    assert r.status_code == 200
    body = r.json()
    assert body["status"] == "ok"
    assert body["mongo_connected"] is True
    assert body["admin_email_configured"] == ADMIN_EMAIL


# ---------- Admin login (smoke duplicate to confirm 200) ----------
def test_admin_login_returns_token(s):
    r = s.post(
        f"{BASE_URL}/api/admin/login",
        json={"email": ADMIN_EMAIL, "password": ADMIN_PASSWORD},
        timeout=15,
    )
    assert r.status_code == 200
    j = r.json()
    assert j["is_admin"] is True
    assert j["token_type"] == "bearer"


def test_admin_login_wrong_password(s):
    r = s.post(
        f"{BASE_URL}/api/admin/login",
        json={"email": ADMIN_EMAIL, "password": "WRONG"},
        timeout=15,
    )
    assert r.status_code in (400, 401, 403)


# ---------- Admin protected listing endpoints ----------
@pytest.mark.parametrize(
    "path",
    [
        "/api/admin/users",
        "/api/admin/stats",
        "/api/admin/system-check",
        "/api/admin/ua-versions",
    ],
)
def test_admin_protected_endpoints_smoke(admin_headers, path):
    r = requests.get(f"{BASE_URL}{path}", headers=admin_headers, timeout=20)
    # System-check + ua-versions may legitimately return non-200 in restricted envs
    # but they must not 5xx with admin token.
    assert r.status_code < 500, f"{path} 5xx: {r.status_code} {r.text[:200]}"
    assert r.status_code in (
        200,
        201,
    ), f"{path} returned {r.status_code} {r.text[:200]}"


# ---------- Public branding ----------
def test_branding_app_name():
    r = requests.get(f"{BASE_URL}/api/branding", timeout=10)
    assert r.status_code == 200
    j = r.json()
    # rebrand asserted in iter_4 — confirm still RealTraffic
    assert j.get("app_name") == "RealTraffic"


# ---------- RUT engine status & jobs listing ----------
def test_rut_engine_status(admin_headers):
    r = requests.get(
        f"{BASE_URL}/api/real-user-traffic/engine-status",
        headers=admin_headers,
        timeout=15,
    )
    # Admin token may 401 on user-scoped routes; either 200 or 401 acceptable, never 5xx.
    assert r.status_code < 500


def test_rut_jobs_listing(admin_headers):
    r = requests.get(
        f"{BASE_URL}/api/real-user-traffic/jobs", headers=admin_headers, timeout=15
    )
    assert r.status_code < 500


# ---------- CPI ----------
@pytest.mark.parametrize(
    "path", ["/api/cpi/offers", "/api/cpi/dashboard/stats"]
)
def test_cpi_endpoints_mounted(path, admin_headers):
    r = requests.get(f"{BASE_URL}{path}", headers=admin_headers, timeout=15)
    # Per iter_4: admin token gets 401 here (admin not in users coll). Just confirm not 404 (mounted) and not 5xx.
    assert r.status_code != 404, f"{path} not mounted (404) — CPI router missing!"
    assert r.status_code < 500


# ---------- Sub-users / form-filler / admin sub-users listing ----------
def test_sub_users_listing(admin_headers):
    r = requests.get(f"{BASE_URL}/api/sub-users", headers=admin_headers, timeout=15)
    assert r.status_code < 500


def test_form_filler_jobs_listing(admin_headers):
    r = requests.get(
        f"{BASE_URL}/api/form-filler/jobs", headers=admin_headers, timeout=15
    )
    assert r.status_code < 500


# ---------- User register / login / /api/auth/me round trip ----------
@pytest.fixture(scope="module")
def test_user(s):
    email = f"TEST_iter5_{int(time.time())}_{uuid.uuid4().hex[:6]}@example.com"
    password = "TestPass123!"
    r = s.post(
        f"{BASE_URL}/api/auth/register",
        json={"email": email, "password": password, "name": "Iter5 Tester"},
        timeout=20,
    )
    assert r.status_code in (200, 201), f"register failed: {r.status_code} {r.text[:200]}"
    return {"email": email, "password": password}


def test_user_login_and_me(s, test_user):
    r = s.post(
        f"{BASE_URL}/api/auth/login",
        json={"email": test_user["email"], "password": test_user["password"]},
        timeout=15,
    )
    assert r.status_code == 200, r.text[:200]
    tok = r.json().get("access_token")
    assert tok and len(tok) > 20

    me = requests.get(
        f"{BASE_URL}/api/auth/me",
        headers={"Authorization": f"Bearer {tok}"},
        timeout=15,
    )
    assert me.status_code == 200, me.text[:200]
    body = me.json()
    assert body.get("email") == test_user["email"]


# ---------- RUT validation tests are covered by iter_4 (test_rebrand_iter4.py) which
# does the full user→activate→link→POST flow. We re-run that suite separately. ----------

