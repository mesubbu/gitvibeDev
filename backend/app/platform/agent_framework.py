from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Awaitable, Callable

from .event_bus import AsyncEventBus

AgentHandler = Callable[[dict[str, Any], "AgentContext"], Awaitable[dict[str, Any]]]


class AgentFrameworkError(RuntimeError):
    def __init__(self, message: str, *, status_code: int = 400) -> None:
        super().__init__(message)
        self.status_code = status_code


@dataclass(frozen=True)
class AgentSpec:
    name: str
    version: str
    description: str
    capabilities: set[str] = field(default_factory=set)
    extension_points: set[str] = field(default_factory=set)

    def as_dict(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "version": self.version,
            "description": self.description,
            "capabilities": sorted(self.capabilities),
            "extension_points": sorted(self.extension_points),
        }


@dataclass(frozen=True)
class AgentContext:
    actor: str
    role: str
    request_id: str
    git_provider: str
    oauth_owner: str | None = None
    metadata: dict[str, Any] = field(default_factory=dict)


class AgentFramework:
    def __init__(self, *, event_bus: AsyncEventBus) -> None:
        self._event_bus = event_bus
        self._agents: dict[str, tuple[AgentSpec, AgentHandler]] = {}

    def register_agent(self, spec: AgentSpec, handler: AgentHandler) -> None:
        if not spec.name.strip():
            raise AgentFrameworkError("Agent name cannot be empty.")
        self._agents[spec.name] = (spec, handler)

    def list_agents(self) -> list[dict[str, Any]]:
        return [
            spec.as_dict()
            for spec, _ in sorted(self._agents.values(), key=lambda item: item[0].name)
        ]

    async def run_agent(
        self,
        *,
        agent_name: str,
        payload: dict[str, Any],
        context: AgentContext,
    ) -> dict[str, Any]:
        entry = self._agents.get(agent_name)
        if entry is None:
            raise AgentFrameworkError(f"Unknown agent '{agent_name}'.", status_code=404)
        spec, handler = entry
        await self._event_bus.publish(
            "agent.started",
            {
                "agent": spec.name,
                "version": spec.version,
                "request_id": context.request_id,
                "actor": context.actor,
            },
            source="agent-framework",
        )
        result = await handler(payload, context)
        await self._event_bus.publish(
            "agent.completed",
            {
                "agent": spec.name,
                "version": spec.version,
                "request_id": context.request_id,
                "status": result.get("status", "completed"),
            },
            source="agent-framework",
        )
        return {
            "agent": spec.name,
            "version": spec.version,
            "result": result,
        }
