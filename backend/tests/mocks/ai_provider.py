from __future__ import annotations


class MockAIProvider:
    provider_name = "mock-ai"
    model_name = "mock-model"

    def __init__(self, fail: bool = False) -> None:
        self.fail = fail

    async def health(self) -> tuple[bool, str]:
        return True, "ok"

    async def review(self, *, system_prompt: str, user_prompt: str) -> str:
        if self.fail:
            raise RuntimeError("mock AI failure")
        snippet = user_prompt.replace("\n", " ")[:80]
        return f"mock-review:{snippet}"
