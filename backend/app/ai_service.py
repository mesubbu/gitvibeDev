from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Any

import httpx


class AIProviderError(RuntimeError):
    """Raised when the active AI provider cannot process a request."""


class BaseAIProvider(ABC):
    model_name: str
    provider_name: str

    @abstractmethod
    async def health(self) -> tuple[bool, str]:
        raise NotImplementedError

    @abstractmethod
    async def review(self, *, system_prompt: str, user_prompt: str) -> str:
        raise NotImplementedError


class OllamaProvider(BaseAIProvider):
    def __init__(self, *, base_url: str, model_name: str, timeout_seconds: float = 30.0) -> None:
        self._base_url = base_url.rstrip("/")
        self.model_name = model_name
        self.provider_name = "ollama"
        self._timeout_seconds = timeout_seconds

    async def health(self) -> tuple[bool, str]:
        endpoint = f"{self._base_url}/api/tags"
        try:
            async with httpx.AsyncClient(timeout=8.0) as client:
                response = await client.get(endpoint)
                response.raise_for_status()
            return True, "ok"
        except (httpx.RequestError, httpx.HTTPStatusError) as exc:
            return False, str(exc)

    async def review(self, *, system_prompt: str, user_prompt: str) -> str:
        endpoint = f"{self._base_url}/api/chat"
        payload = {
            "model": self.model_name,
            "stream": False,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
        }
        try:
            async with httpx.AsyncClient(timeout=self._timeout_seconds) as client:
                response = await client.post(endpoint, json=payload)
                response.raise_for_status()
                body = response.json()
        except (httpx.RequestError, httpx.HTTPStatusError, ValueError) as exc:
            raise AIProviderError(f"Ollama request failed: {exc}") from exc
        message = body.get("message") if isinstance(body, dict) else None
        content = message.get("content") if isinstance(message, dict) else None
        if not isinstance(content, str) or not content.strip():
            raise AIProviderError("Ollama response is missing review content.")
        return content


class OpenAICompatibleProvider(BaseAIProvider):
    def __init__(
        self,
        *,
        base_url: str,
        api_key: str,
        model_name: str,
        timeout_seconds: float = 30.0,
    ) -> None:
        self._base_url = base_url.rstrip("/")
        self._api_key = api_key
        self.model_name = model_name
        self.provider_name = "openai_compatible"
        self._timeout_seconds = timeout_seconds

    def _headers(self) -> dict[str, str]:
        if not self._api_key:
            raise AIProviderError("OPENAI_API_KEY is required for OpenAI-compatible provider.")
        return {
            "Authorization": f"Bearer {self._api_key}",
            "Content-Type": "application/json",
        }

    async def health(self) -> tuple[bool, str]:
        try:
            async with httpx.AsyncClient(timeout=8.0) as client:
                response = await client.get(f"{self._base_url}/models", headers=self._headers())
                response.raise_for_status()
            return True, "ok"
        except (httpx.RequestError, httpx.HTTPStatusError, AIProviderError) as exc:
            return False, str(exc)

    async def review(self, *, system_prompt: str, user_prompt: str) -> str:
        payload = {
            "model": self.model_name,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
            "temperature": 0.2,
        }
        try:
            async with httpx.AsyncClient(timeout=self._timeout_seconds) as client:
                response = await client.post(
                    f"{self._base_url}/chat/completions",
                    json=payload,
                    headers=self._headers(),
                )
                response.raise_for_status()
                body = response.json()
        except (httpx.RequestError, httpx.HTTPStatusError, ValueError, AIProviderError) as exc:
            raise AIProviderError(f"OpenAI-compatible request failed: {exc}") from exc
        choices = body.get("choices") if isinstance(body, dict) else None
        if not isinstance(choices, list) or not choices:
            raise AIProviderError("OpenAI-compatible response has no choices.")
        first_choice = choices[0]
        if not isinstance(first_choice, dict):
            raise AIProviderError("OpenAI-compatible response choice is invalid.")
        message = first_choice.get("message")
        content = message.get("content") if isinstance(message, dict) else None
        if not isinstance(content, str) or not content.strip():
            raise AIProviderError("OpenAI-compatible response is missing review content.")
        return content


@dataclass(frozen=True)
class AIReviewRequestContext:
    owner: str
    repo: str
    pull_number: int
    title: str
    body: str
    diff: str
    focus: str = ""


class AIReviewService:
    SYSTEM_PROMPT = (
        "You are a strict senior code reviewer. Focus on correctness, security, and maintainability. "
        "Return concise markdown with sections: Summary, Critical Issues, Improvements."
    )

    def __init__(
        self,
        *,
        provider_name: str,
        ollama_base_url: str,
        ollama_model: str,
        openai_base_url: str,
        openai_api_key: str,
        openai_model: str,
    ) -> None:
        resolved = provider_name.strip().lower()
        if resolved == "ollama":
            self._provider: BaseAIProvider = OllamaProvider(
                base_url=ollama_base_url,
                model_name=ollama_model,
            )
        elif resolved in {"openai", "openai-compatible", "openai_compatible"}:
            self._provider = OpenAICompatibleProvider(
                base_url=openai_base_url,
                api_key=openai_api_key,
                model_name=openai_model,
            )
        else:
            raise ValueError(f"Unsupported AI provider: {provider_name}")

    @property
    def provider_name(self) -> str:
        return self._provider.provider_name

    @property
    def model_name(self) -> str:
        return self._provider.model_name

    async def health(self) -> tuple[bool, str]:
        return await self._provider.health()

    @staticmethod
    def _clip_diff(diff: str, max_chars: int = 30_000) -> str:
        text = diff.strip()
        if len(text) <= max_chars:
            return text
        return f"{text[:max_chars]}\n\n[diff truncated to {max_chars} chars]"

    @classmethod
    def _build_user_prompt(cls, context: AIReviewRequestContext) -> str:
        focus_line = context.focus.strip() if context.focus else "General quality review."
        return (
            f"Repository: {context.owner}/{context.repo}\n"
            f"PR: #{context.pull_number}\n"
            f"Title: {context.title}\n"
            f"Focus: {focus_line}\n"
            f"Description:\n{context.body or '(no description)'}\n\n"
            "Unified diff:\n"
            f"{cls._clip_diff(context.diff)}\n"
        )

    async def review_pull_request(self, context: AIReviewRequestContext) -> dict[str, Any]:
        prompt = self._build_user_prompt(context)
        review_text = await self._provider.review(
            system_prompt=self.SYSTEM_PROMPT,
            user_prompt=prompt,
        )
        return {
            "provider": self.provider_name,
            "model": self.model_name,
            "review": review_text,
            "repo": f"{context.owner}/{context.repo}",
            "pull_number": context.pull_number,
        }
