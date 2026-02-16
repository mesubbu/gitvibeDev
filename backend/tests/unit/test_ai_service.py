from __future__ import annotations

import pytest

from app.ai_service import AIReviewRequestContext, AIReviewService
from tests.mocks.ai_provider import MockAIProvider


pytestmark = [pytest.mark.unit, pytest.mark.asyncio]


async def test_ai_review_service_uses_mock_provider() -> None:
    service = AIReviewService(
        provider_name="ollama",
        ollama_base_url="http://unused",
        ollama_model="llama",
        openai_base_url="http://unused",
        openai_api_key="",
        openai_model="gpt",
    )
    service._provider = MockAIProvider()  # type: ignore[attr-defined]

    payload = await service.review_pull_request(
        AIReviewRequestContext(
            owner="demo",
            repo="alpha",
            pull_number=1,
            title="Title",
            body="Body",
            diff="diff --git",
        )
    )

    assert payload["provider"] == "mock-ai"
    assert payload["model"] == "mock-model"
    assert payload["review"].startswith("mock-review:")
