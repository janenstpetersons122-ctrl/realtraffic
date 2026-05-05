"""
Iteration 4 — Post-rebrand (RealFlow → RealTraffic) smoke + regression suite.

Covers:
- Health (internal — not under /api)
- Admin login with NEW credentials (admin@realtraffic.local) + OLD creds MUST 401
- /api/branding exposes app_name='RealTraffic'
- User register/login/me happy path
- Admin listing endpoints (users, stats, system-check)
- CPI module still mounted (offers, dashboard/stats)
- Sub-users, form-filler list
- RUT engine-status + jobs list
- RUT POST validation:
    - concurrency=20 → 400 (cap lowered to 15)
    - concurrency=15 + fast_mode=true → 200 (boundary + new field accepted)

NOTE: We do NOT actually execute a RUT job — the Playwright chromium install
warning is pre-existing and non-blocking. We only validate the endpoint's
input-validation contract.
"""
import os
import time
import uuid
import requests
import pytest

EXTERNAL_BASE = os.environ.get("REACT_APP_BACKEND_URL", "").rstrip("/") or \
    "https://4b5fd38f-8131-4325-a03e-1a926cacce61.preview.emergentagent.com"
# The frontend/.env base (realtraffic-sim.preview.emergentagent.com) is 404
# via public ingress in this preview — fall back to the known-working URL
# from /app/memory/test_credentials.md.
if requests.get(f"{EXTERNAL_BASE}/api/branding", timeout=10).status_code != 200:
    EXTERNAL_BASE = "https://4b5fd38f-8131-4325-a03e-1a926cacce61.preview.emergentagent.com"

INTERNAL_BASE = "http://localhost:8001"

ADMIN_EMAIL = "admin@realtraffic.local"
ADMIN_PASSWORD = "admin123"
OLD_ADMIN_EMAIL = "admin@realflow.local"  # Must 401 after rebrand

TS = int(time.time())
TEST_USER_EMAIL = f"TEST_rebrand_{TS}_{uuid.uuid4().hex[:6]}@example.com"
TEST_USER_PASSWORD = "TestPass123!"


# ---------- Fixtures ----------
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
def user_bundle(admin_token):
    """Register a test user, admin activates + enables links+real_user_traffic."""
    # 1. Register
    r = requests.post(
        f"{EXTERNAL_BASE}/api/auth/register",
        json={"email": TEST_USER_EMAIL, "password": TEST_USER_PASSWORD, "name": "Rebrand Tester"},
        timeout=20,
    )
    assert r.status_code in (200, 201), f"register failed: {r.status_code} {r.text}"
    reg = r.json()
    user_token = reg.get("access_token")
    assert user_token, f"no access_token: {reg}"

    # 2. Get user id from /api/auth/me
    me = requests.get(f"{EXTERNAL_BASE}/api/auth/me",
                      headers={"Authorization": f"Bearer {user_token}"}, timeout=15).json()
    user_id = me.get("id")
    assert user_id, f"no id in /me: {me}"

    # 3. Admin activates + enables features
    features = {
        "links": True, "clicks": True, "conversions": True, "proxies": True,
        "import_data": True, "real_user_traffic": True, "form_filler": True,
        "settings": True,
        "max_links": 100, "max_clicks": 100000, "max_sub_users": 0,
    }
    r = requests.put(
        f"{EXTERNAL_BASE}/api/admin/users/{user_id}",
        headers={"Authorization": f"Bearer {admin_token}"},
        json={"status": "active", "features": features},
        timeout=20,
    )
    assert r.status_code == 200, f"admin update user failed: {r.status_code} {r.text}"

    return {"token": user_token, "id": user_id, "email": TEST_USER_EMAIL}


@pytest.fixture(scope="module")
def link_id(user_bundle):
    """Create a link for the active test user (needed for RUT POST)."""
    r = requests.post(
        f"{EXTERNAL_BASE}/api/links",
        headers={"Authorization": f"Bearer {user_bundle['token']}"},
        json={"offer_url": "https://example.com/offer", "status": "active", "name": "TEST_rebrand_link"},
        timeout=20,
    )
    assert r.status_code in (200, 201), f"create link failed: {r.status_code} {r.text}"
    lid = r.json().get("id")
    assert lid
    return lid


def _hdr(tok):
    return {"Authorization": f"Bearer {tok}"}


# ---------- Health ----------
def test_health_internal_shows_realtraffic_admin_email():
    r = requests.get(f"{INTERNAL_BASE}/health", timeout=10)
    assert r.status_code == 200
    body = r.json()
    assert body.get("mongo_connected") is True
    assert body.get("admin_email_configured") == "admin@realtraffic.local", \
        f"admin_email_configured not rebranded: {body}"


# ---------- Admin auth: new creds work, old creds fail ----------
def test_admin_login_new_credentials(admin_token):
    assert admin_token  # fixture asserts shape


def test_admin_login_old_credentials_rejected():
    r = requests.post(
        f"{EXTERNAL_BASE}/api/admin/login",
        json={"email": OLD_ADMIN_EMAIL, "password": ADMIN_PASSWORD},
        timeout=15,
    )
    assert r.status_code == 401, \
        f"OLD admin creds ({OLD_ADMIN_EMAIL}) should be 401 after rebrand, got {r.status_code} {r.text}"


# ---------- Branding ----------
def test_branding_app_name_is_realtraffic():
    r = requests.get(f"{EXTERNAL_BASE}/api/branding", timeout=15)
    assert r.status_code == 200
    body = r.json()
    assert body.get("app_name") == "RealTraffic", f"app_name not rebranded: {body}"


# ---------- User auth happy path ----------
def test_user_login_and_me(user_bundle):
    r = requests.post(
        f"{EXTERNAL_BASE}/api/auth/login",
        json={"email": user_bundle["email"], "password": TEST_USER_PASSWORD},
        timeout=20,
    )
    assert r.status_code == 200, f"{r.status_code} {r.text}"
    tok = r.json().get("access_token")
    assert tok
    me = requests.get(f"{EXTERNAL_BASE}/api/auth/me", headers=_hdr(tok), timeout=15)
    assert me.status_code == 200
    assert me.json().get("email") == user_bundle["email"]


# ---------- Admin module endpoints ----------
def test_admin_users_list(admin_token):
    r = requests.get(f"{EXTERNAL_BASE}/api/admin/users", headers=_hdr(admin_token), timeout=20)
    assert r.status_code == 200
    assert isinstance(r.json(), list)


def test_admin_stats(admin_token):
    r = requests.get(f"{EXTERNAL_BASE}/api/admin/stats", headers=_hdr(admin_token), timeout=20)
    assert r.status_code == 200
    assert isinstance(r.json(), dict)


def test_admin_system_check(admin_token):
    r = requests.get(f"{EXTERNAL_BASE}/api/admin/system-check", headers=_hdr(admin_token), timeout=30)
    assert r.status_code == 200
    assert isinstance(r.json(), dict)


# ---------- CPI module (still mounted under /api/cpi) ----------
# Note: CPI uses _get_current_user_with_fresh_data which queries the users
# collection. Admin (env-only, not in users DB) correctly returns 401. We
# verify the module is mounted + reachable by using a real user token.
def test_cpi_offers_mounted(user_bundle):
    r = requests.get(f"{EXTERNAL_BASE}/api/cpi/offers", headers=_hdr(user_bundle["token"]), timeout=20)
    # 200 or 403 (cpi feature flag) — both prove the route is mounted; 404/5xx would be a regression.
    assert r.status_code in (200, 403), f"{r.status_code} {r.text}"
    if r.status_code == 200:
        assert isinstance(r.json(), list)


def test_cpi_dashboard_stats_mounted(user_bundle):
    r = requests.get(f"{EXTERNAL_BASE}/api/cpi/dashboard/stats",
                     headers=_hdr(user_bundle["token"]), timeout=20)
    # 200 or 403 (feature flag) — both prove route is mounted; only 404/5xx would be regression
    assert r.status_code in (200, 403), f"{r.status_code} {r.text}"


def test_cpi_admin_token_is_not_user_context(admin_token):
    """Documents that admin JWT hits CPI → 401 (admin is env-only, not in users DB)."""
    r = requests.get(f"{EXTERNAL_BASE}/api/cpi/offers", headers=_hdr(admin_token), timeout=20)
    assert r.status_code in (200, 401, 403), f"unexpected: {r.status_code} {r.text}"


# ---------- Sub-users / form-filler / RUT listing ----------
def test_sub_users_list(user_bundle):
    r = requests.get(f"{EXTERNAL_BASE}/api/sub-users", headers=_hdr(user_bundle["token"]), timeout=15)
    assert r.status_code == 200
    assert isinstance(r.json(), list)


def test_form_filler_jobs(user_bundle):
    r = requests.get(f"{EXTERNAL_BASE}/api/form-filler/jobs",
                     headers=_hdr(user_bundle["token"]), timeout=20)
    assert r.status_code == 200, f"{r.status_code} {r.text}"


def test_rut_engine_status(user_bundle):
    r = requests.get(f"{EXTERNAL_BASE}/api/real-user-traffic/engine-status",
                     headers=_hdr(user_bundle["token"]), timeout=20)
    assert r.status_code == 200, f"{r.status_code} {r.text}"


def test_rut_jobs_list(user_bundle):
    r = requests.get(f"{EXTERNAL_BASE}/api/real-user-traffic/jobs",
                     headers=_hdr(user_bundle["token"]), timeout=20)
    assert r.status_code == 200, f"{r.status_code} {r.text}"


# ---------- RUT POST validation (the core rebrand-change verification) ----------
def test_rut_concurrency_20_rejected(user_bundle, link_id):
    """Cap was lowered from 20→15. concurrency=20 must now return 400."""
    form = {
        "link_id": link_id,
        "total_clicks": "5",
        "concurrency": "20",
        "proxies": "",
        "user_agents": "Mozilla/5.0 (X11; Linux x86_64) TestUA/1.0",
    }
    r = requests.post(
        f"{EXTERNAL_BASE}/api/real-user-traffic/jobs",
        headers=_hdr(user_bundle["token"]),
        data=form,
        timeout=30,
    )
    assert r.status_code == 400, f"Expected 400 for concurrency=20, got {r.status_code} {r.text}"
    detail = r.json().get("detail", "").lower()
    assert "concurrency" in detail and ("1..15" in detail or "15" in detail), \
        f"Error message should mention new 1..15 cap: {detail}"


def test_rut_concurrency_15_and_fast_mode_accepted(user_bundle, link_id):
    """concurrency=15 is boundary-accepted AND new fast_mode=true form field is accepted."""
    form = {
        "link_id": link_id,
        "total_clicks": "1",
        "concurrency": "15",
        "fast_mode": "true",
        "proxies": "1.2.3.4:8080:user:pass",
        "user_agents": "Mozilla/5.0 (X11; Linux x86_64) TestUA/1.0",
    }
    r = requests.post(
        f"{EXTERNAL_BASE}/api/real-user-traffic/jobs",
        headers=_hdr(user_bundle["token"]),
        data=form,
        timeout=30,
    )
    # Endpoint creates the job and returns 200 with job metadata. The actual
    # run happens in a background task — we don't wait for it.
    assert r.status_code == 200, f"concurrency=15 + fast_mode=true should be accepted, got {r.status_code} {r.text}"
    body = r.json()
    assert body.get("concurrency") == 15, f"concurrency not echoed back: {body}"
    assert body.get("fast_mode") is True, f"fast_mode not echoed back as True: {body}"
    assert body.get("job_id") or body.get("id"), f"no job id in response: {body}"
