from __future__ import annotations

import time

import pytest

from app import main as app_main
from tests.mocks.ai_provider import MockAIProvider


pytestmark = [pytest.mark.integration]


def test_async_ai_job_flow_completes(client, monkeypatch) -> None:
    original_provider = app_main.ai_review_service._provider
    monkeypatch.setattr(app_main.ai_review_service, "_provider", MockAIProvider())
    try:
        queued = client.post(
            "/api/ai/review/jobs",
            json={
                "owner": "demo-org",
                "repo": "platform-api",
                "pull_number": 42,
                "git_provider": "demo",
                "focus": "security",
                "max_retries": 1,
            },
        )
        assert queued.status_code == 200
        job_id = queued.json()["job"]["id"]

        deadline = time.time() + 5
        while time.time() < deadline:
            status = client.get(f"/api/jobs/{job_id}")
            assert status.status_code == 200
            payload = status.json()["job"]
            if payload["status"] == "completed":
                assert payload["result"]["provider"] == "mock-ai"
                return
            time.sleep(0.05)
        raise AssertionError("AI review job did not complete")
    finally:
        monkeypatch.setattr(app_main.ai_review_service, "_provider", original_provider)


def test_workflow_pipeline_runs_with_mock_ai(client, monkeypatch) -> None:
    original_provider = app_main.ai_review_service._provider
    monkeypatch.setattr(app_main.ai_review_service, "_provider", MockAIProvider())
    try:
        response = client.post(
            "/api/workflows/pr-review-pipeline/run",
            json={
                "git_provider": "demo",
                "payload": {
                    "owner": "demo-org",
                    "repo": "platform-api",
                    "pull_number": 42,
                    "focus": "regression",
                },
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert data["workflow"] == "pr-review-pipeline"
        assert len(data["steps"]) == 3
        assert data["steps"][1]["result"]["result"]["provider"] == "mock-ai"
    finally:
        monkeypatch.setattr(app_main.ai_review_service, "_provider", original_provider)
