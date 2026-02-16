from __future__ import annotations

import os
import tempfile
import time
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

runtime_dir = Path(tempfile.gettempdir()) / "gitvibedev-pytest-runtime"
runtime_dir.mkdir(parents=True, exist_ok=True)

os.environ["DEMO_MODE"] = "true"
os.environ["FAST_BOOT"] = "true"
os.environ["VAULT_FILE"] = str(runtime_dir / "vault.enc")
os.environ["AUDIT_LOG_FILE"] = str(runtime_dir / "audit.log")
os.environ["PLUGIN_SANDBOX_ENABLED"] = "false"
os.environ["PLUGIN_ALLOWLIST"] = ""

from app import main as app_main


def _reset_job_queue_state() -> None:
    app_main.job_queue._jobs = {}
    app_main.job_queue._queue = []
    app_main.vault.set(
        app_main.job_queue.STATE_KEY,
        {"jobs": {}, "queue": [], "updated_at": int(time.time())},
    )


@pytest.fixture(autouse=True)
def reset_global_state() -> None:
    app_main.demo_data.seed()
    app_main.event_bus._recent_events.clear()
    _reset_job_queue_state()
    yield
    _reset_job_queue_state()


@pytest.fixture
def client() -> TestClient:
    with TestClient(app_main.app) as test_client:
        yield test_client


@pytest.fixture
def admin_tokens(client: TestClient) -> dict[str, str]:
    response = client.post(
        "/api/auth/token",
        headers={"x-bootstrap-token": app_main.security_config.bootstrap_admin_token},
        json={"username": "qa-admin", "role": "admin"},
    )
    assert response.status_code == 200
    return response.json()
