from __future__ import annotations

import pytest

pytestmark = [pytest.mark.regression]


def test_legacy_pulls_route_shape_is_preserved(client) -> None:
    response = client.get("/api/repos/platform-api/pulls")

    assert response.status_code == 200
    payload = response.json()
    assert set(payload.keys()) == {"repo", "pull_requests"}
    assert payload["repo"] == "platform-api"


def test_plugin_allowlist_failure_shape(client, admin_tokens) -> None:
    response = client.post(
        "/api/plugins/non-existent/run",
        headers={
            "Authorization": f"Bearer {admin_tokens['access_token']}",
            "x-csrf-token": admin_tokens["csrf_token"],
        },
        json={"args": []},
    )

    assert response.status_code == 403
    assert "allowlist" in response.json()["detail"].lower()


def test_csrf_required_for_mutating_plugin_route(client, admin_tokens) -> None:
    response = client.post(
        "/api/plugins/health-probe/run",
        headers={"Authorization": f"Bearer {admin_tokens['access_token']}"},
        json={"args": []},
    )

    assert response.status_code == 403
    assert "csrf" in response.json()["detail"].lower()
