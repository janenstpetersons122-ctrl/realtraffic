"""
Iteration 3 — Post-clone backend smoke test for RealTraffic.
Covers ~15 endpoints across auth, admin, branding, AI, sub-users, form-filler,
real-user-traffic, and CPI modules. Goal: confirm no 5xx after fresh clone.
"""
import os
import time
import uuid
import requests
import pytest

EXTERNAL_BASE = os.environ.get("REACT_APP_BACKEND_URL", "").rstrip("/") or \
    "https://4b5fd38f-8131-4325-a03e-1a926cacce61.preview.emergentagent.com"
INTERNAL_BASE = "http://localhost:8001"  # /health is NOT under /api so ingress routes it to frontend

ADMIN_EMAIL = "admin@realtraffic.local"
ADMIN_PASSWORD = "admin123"

TS = int(time.time())
TEST_USER_EMAIL = f"TEST_smoke_{TS}_{uuid.uuid4().hex[:6]}@example.com"
TEST_USER_PASSWORD = "TestPass123!"


@pytest.fixture(scope="module")
def admin_token():
    r = requests.post(
        f"{EXTERNAL_BASE}/api/admin/login",
        json={"email": ADMIN_EMAIL, "password": ADMIN_PASSWORD},
        timeout=20,
    )
    assert r.status_code == 200, f"admin login failed: {r.status_code} {r.text}"
    data = r.json()
    assert data.get("is_admin") is True
    assert isinstance(data.get("access_token"), str) and data["access_token"]
    return data["access_token"]


@pytest.fixture(scope="module")
def user_token():
    # Register
    r = requests.post(
        f"{EXTERNAL_BASE}/api/auth/register",
        json={"email": TEST_USER_EMAIL, "password": TEST_USER_PASSWORD, "name": "Smoke Tester"},
        timeout=20,
    )
    assert r.status_code in (200, 201), f"register failed: {r.status_code} {r.text}"
    body = r.json()
    tok = body.get("access_token")
    assert isinstance(tok, str) and tok, f"no access_token in register response: {body}"
    return tok


def _hdr(tok):
    return {"Authorization": f"Bearer {tok}"}


# ---------- Health ----------
def test_health_internal():
    """/health is at root (no /api), so use internal port — ingress only routes /api to backend."""
    r = requests.get(f"{INTERNAL_BASE}/health", timeout=10)
    assert r.status_code == 200
    body = r.json()
    assert body.get("mongo_connected") is True
    assert body.get("status") == "ok"


# ---------- Auth ----------
def test_admin_login(admin_token):
    assert admin_token  # fixture asserts shape


def test_user_register_and_login(user_token):
    # Now login with the same creds
    r = requests.post(
        f"{EXTERNAL_BASE}/api/auth/login",
        json={"email": TEST_USER_EMAIL, "password": TEST_USER_PASSWORD},
        timeout=20,
    )
    assert r.status_code == 200, f"{r.status_code} {r.text}"
    data = r.json()
    assert isinstance(data.get("access_token"), str) and data["access_token"]


def test_auth_me(user_token):
    r = requests.get(f"{EXTERNAL_BASE}/api/auth/me", headers=_hdr(user_token), timeout=15)
    assert r.status_code == 200
    body = r.json()
    assert body.get("email") == TEST_USER_EMAIL


# ---------- Admin ----------
def test_admin_users_list(admin_token):
    r = requests.get(f"{EXTERNAL_BASE}/api/admin/users", headers=_hdr(admin_token), timeout=20)
    assert r.status_code == 200
    body = r.json()
    assert isinstance(body, list)


def test_admin_stats(admin_token):
    r = requests.get(f"{EXTERNAL_BASE}/api/admin/stats", headers=_hdr(admin_token), timeout=20)
    assert r.status_code == 200
    body = r.json()
    assert isinstance(body, dict)


def test_admin_system_check(admin_token):
    r = requests.get(f"{EXTERNAL_BASE}/api/admin/system-check", headers=_hdr(admin_token), timeout=30)
    assert r.status_code == 200
    body = r.json()
    assert isinstance(body, dict)


def test_admin_ua_versions(admin_token):
    r = requests.get(f"{EXTERNAL_BASE}/api/admin/ua-versions", headers=_hdr(admin_token), timeout=20)
    assert r.status_code == 200
    body = r.json()
    assert isinstance(body, dict)


# ---------- Branding (public) ----------
def test_branding_public():
    r = requests.get(f"{EXTERNAL_BASE}/api/branding", timeout=15)
    assert r.status_code == 200
    body = r.json()
    assert isinstance(body, dict)


# ---------- AI / Notification settings ----------
def test_ai_settings(user_token):
    r = requests.get(f"{EXTERNAL_BASE}/api/ai-settings", headers=_hdr(user_token), timeout=15)
    assert r.status_code == 200


def test_user_notification_settings(user_token):
    r = requests.get(
        f"{EXTERNAL_BASE}/api/user/notification-settings",
        headers=_hdr(user_token),
        timeout=15,
    )
    assert r.status_code == 200


# ---------- Sub-users ----------
def test_sub_users_list(user_token):
    r = requests.get(f"{EXTERNAL_BASE}/api/sub-users", headers=_hdr(user_token), timeout=15)
    assert r.status_code == 200
    body = r.json()
    assert isinstance(body, list)


# ---------- Form-filler ----------
def test_form_filler_jobs(user_token):
    r = requests.get(f"{EXTERNAL_BASE}/api/form-filler/jobs", headers=_hdr(user_token), timeout=20)
    # User probably doesn't have form_filler feature enabled — 200 with [] OR 403 is OK; reject 5xx
    assert r.status_code in (200, 401, 403), f"{r.status_code} {r.text}"
    if r.status_code == 200:
        body = r.json()
        # Endpoint returns {"jobs": [...]} dict shape — accept dict or list
        assert isinstance(body, (list, dict))


# ---------- Real user traffic ----------
def test_rut_engine_status(user_token):
    r = requests.get(
        f"{EXTERNAL_BASE}/api/real-user-traffic/engine-status",
        headers=_hdr(user_token),
        timeout=20,
    )
    assert r.status_code in (200, 401, 403), f"{r.status_code} {r.text}"


def test_rut_jobs_list(user_token):
    r = requests.get(
        f"{EXTERNAL_BASE}/api/real-user-traffic/jobs",
        headers=_hdr(user_token),
        timeout=20,
    )
    assert r.status_code in (200, 401, 403), f"{r.status_code} {r.text}"


# ---------- CPI ----------
def test_cpi_offers_admin(admin_token):
    r = requests.get(f"{EXTERNAL_BASE}/api/cpi/offers", headers=_hdr(admin_token), timeout=20)
    assert r.status_code in (200, 401, 403), f"{r.status_code} {r.text}"
    if r.status_code == 200:
        assert isinstance(r.json(), list)


def test_cpi_offers_user(user_token):
    r = requests.get(f"{EXTERNAL_BASE}/api/cpi/offers", headers=_hdr(user_token), timeout=20)
    # CPI listing may require feature flag — accept 200/401/403 but no 5xx
    assert r.status_code in (200, 401, 403), f"{r.status_code} {r.text}"


def test_cpi_dashboard_stats_admin(admin_token):
    r = requests.get(f"{EXTERNAL_BASE}/api/cpi/dashboard/stats", headers=_hdr(admin_token), timeout=20)
    assert r.status_code in (200, 401, 403), f"{r.status_code} {r.text}"
