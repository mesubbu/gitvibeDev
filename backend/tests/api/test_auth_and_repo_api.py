from __future__ import annotations

import pytest

pytestmark = [pytest.mark.api]


def test_auth_status_and_repos(client) -> None:
    status = client.get("/api/auth/status")
    repos = client.get("/api/repos")

    assert status.status_code == 200
    assert status.json()["mode"] == "demo"
    assert repos.status_code == 200
    assert repos.json()["provider"] == "demo"
    assert len(repos.json()["repos"]) >= 1


def test_plugin_execution_requires_auth(client) -> None:
    response = client.post("/api/plugins/health-probe/run", json={"args": []})
    assert response.status_code == 401


def test_plugin_sdk_execution_with_admin_token(client, admin_tokens) -> None:
    response = client.post(
        "/api/plugins/health-probe/run",
        headers={
            "Authorization": f"Bearer {admin_tokens['access_token']}",
            "x-csrf-token": admin_tokens["csrf_token"],
        },
        json={"args": ["ping"], "required_permission": "plugin:execute"},
    )

    assert response.status_code == 200
    payload = response.json()
    assert payload["runtime"] == "sdk"
    assert payload["version"] == "1.0.0"
    assert payload["status"] == "ok"


def test_platform_metadata_endpoints(client) -> None:
    providers = client.get("/api/git/providers")
    boundaries = client.get("/api/platform/service-boundaries")
    plugins = client.get("/api/plugins")
    agents = client.get("/api/agents")
    workflows = client.get("/api/workflows")

    assert providers.status_code == 200
    assert boundaries.status_code == 200
    assert plugins.status_code == 200
    assert agents.status_code == 200
    assert workflows.status_code == 200
