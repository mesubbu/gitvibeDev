from __future__ import annotations

import pytest

from app.github_service import GitHubConfig, GitHubService
from app.security import AuditLogger
from app.vault import LocalVault
from tests.mocks.github_api import MockGitHubAPI


pytestmark = [pytest.mark.unit, pytest.mark.asyncio]


@pytest.fixture
def github_service(tmp_path):
    vault = LocalVault(file_path=str(tmp_path / "vault.enc"), master_key="test-key")
    logger = AuditLogger(file_path=str(tmp_path / "audit.log"))
    service = GitHubService(
        config=GitHubConfig(
            client_id="cid",
            client_secret="secret",
            app_private_key="pk",
            oauth_redirect_uri="http://localhost/callback",
        ),
        vault=vault,
        audit_logger=logger,
    )
    vault.set(service.oauth_vault_key("alice"), {"access_token": "token"})
    return service


async def test_list_repositories_and_issues_filtering(github_service, monkeypatch):
    mock_api = MockGitHubAPI()

    async def fake_json(method, path, **kwargs):
        return mock_api.json_response(
            method,
            path,
            params=kwargs.get("params"),
            json_body=kwargs.get("json_body"),
        )

    monkeypatch.setattr(github_service, "_github_api_json", fake_json)

    repos = await github_service.list_repositories(oauth_owner="alice", limit=20)
    issues = await github_service.list_issues(
        owner="demo",
        repo="alpha",
        oauth_owner="alice",
        limit=20,
        state_filter="all",
    )

    assert repos[0]["name"] == "alpha"
    assert len(issues) == 1
    assert issues[0]["number"] == 12


async def test_merge_collaborators_and_pull_context(github_service, monkeypatch):
    mock_api = MockGitHubAPI()

    async def fake_json(method, path, **kwargs):
        return mock_api.json_response(
            method,
            path,
            params=kwargs.get("params"),
            json_body=kwargs.get("json_body"),
        )

    async def fake_request(method, path, **kwargs):
        return mock_api.request_response(method, path)

    monkeypatch.setattr(github_service, "_github_api_json", fake_json)
    monkeypatch.setattr(github_service, "_github_api_request", fake_request)

    merged = await github_service.merge_pull_request(
        owner="demo",
        repo="alpha",
        pull_number=7,
        oauth_owner="alice",
        merge_method="squash",
        commit_title="demo",
    )
    collaborators = await github_service.list_collaborators(
        owner="demo",
        repo="alpha",
        oauth_owner="alice",
        limit=20,
    )
    context = await github_service.get_pull_review_context(
        owner="demo",
        repo="alpha",
        pull_number=7,
        oauth_owner="alice",
    )

    assert merged["merged"] is True
    assert collaborators[0]["login"] == "alice"
    assert "diff --git" in context["diff"]
