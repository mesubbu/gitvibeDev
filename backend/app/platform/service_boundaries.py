from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True)
class ServiceBoundary:
    name: str
    responsibility: str
    owns: list[str]
    depends_on: list[str]
    extension_points: list[str] = field(default_factory=list)

    def as_dict(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "responsibility": self.responsibility,
            "owns": self.owns,
            "depends_on": self.depends_on,
            "extension_points": self.extension_points,
        }


class ServiceBoundaryCatalog:
    def __init__(self) -> None:
        self._boundaries: list[ServiceBoundary] = [
            ServiceBoundary(
                name="api-gateway",
                responsibility="Expose HTTP APIs and keep backward-compatible routes.",
                owns=["backend/app/main.py"],
                depends_on=["auth-security", "git-integration", "plugin-framework", "workflow-engine"],
                extension_points=["api.before_request", "api.after_request"],
            ),
            ServiceBoundary(
                name="auth-security",
                responsibility="JWT, RBAC, CSRF, rate limiting, secure headers, and audit logs.",
                owns=["backend/app/security.py", "backend/app/vault.py"],
                depends_on=[],
            ),
            ServiceBoundary(
                name="git-integration",
                responsibility="Provider abstraction over git hosts (GitHub + future providers).",
                owns=["backend/app/github_service.py", "backend/app/platform/git_providers.py"],
                depends_on=["auth-security"],
                extension_points=["git.provider.register"],
            ),
            ServiceBoundary(
                name="plugin-framework",
                responsibility="Plugin manifest registry, permissions, versioning, SDK runtime, extension hooks.",
                owns=["backend/app/platform/plugin_framework.py", "backend/app/platform/plugin_sdk.py"],
                depends_on=["event-bus", "auth-security"],
                extension_points=["plugin.pre_execute", "plugin.post_execute"],
            ),
            ServiceBoundary(
                name="agent-framework",
                responsibility="Agent registration, capabilities, and execution dispatch.",
                owns=["backend/app/platform/agent_framework.py"],
                depends_on=["event-bus", "plugin-framework"],
                extension_points=["agent.started", "agent.completed"],
            ),
            ServiceBoundary(
                name="workflow-engine",
                responsibility="Composable workflow orchestration across events, agents, and plugins.",
                owns=["backend/app/platform/workflow_engine.py"],
                depends_on=["event-bus", "agent-framework", "plugin-framework"],
                extension_points=["workflow.before_step", "workflow.after_step"],
            ),
            ServiceBoundary(
                name="event-bus",
                responsibility="In-memory event publish/subscribe integration fabric.",
                owns=["backend/app/platform/event_bus.py"],
                depends_on=[],
            ),
            ServiceBoundary(
                name="jobs-runtime",
                responsibility="Persistent job queue with retries and execution status tracking.",
                owns=["backend/app/job_queue.py"],
                depends_on=["auth-security", "event-bus"],
            ),
        ]

    def list_boundaries(self) -> list[dict[str, Any]]:
        return [boundary.as_dict() for boundary in self._boundaries]
