from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

from .agent_framework import AgentContext, AgentFramework
from .event_bus import AsyncEventBus
from .plugin_framework import PluginExecutionContext, PluginFramework, PluginPermissions


class WorkflowEngineError(RuntimeError):
    def __init__(self, message: str, *, status_code: int = 400) -> None:
        super().__init__(message)
        self.status_code = status_code


@dataclass(frozen=True)
class WorkflowStep:
    id: str
    kind: str
    target: str
    config: dict[str, Any] = field(default_factory=dict)

    def as_dict(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "kind": self.kind,
            "target": self.target,
            "config": self.config,
        }


@dataclass(frozen=True)
class WorkflowDefinition:
    name: str
    version: str
    description: str
    steps: list[WorkflowStep]
    extension_points: set[str] = field(default_factory=set)

    def as_dict(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "version": self.version,
            "description": self.description,
            "steps": [step.as_dict() for step in self.steps],
            "extension_points": sorted(self.extension_points),
        }


@dataclass(frozen=True)
class WorkflowExecutionContext:
    actor: str
    role: str
    request_id: str
    git_provider: str
    oauth_owner: str | None = None
    metadata: dict[str, Any] = field(default_factory=dict)


class WorkflowEngine:
    def __init__(
        self,
        *,
        event_bus: AsyncEventBus,
        agent_framework: AgentFramework,
        plugin_framework: PluginFramework,
    ) -> None:
        self._event_bus = event_bus
        self._agent_framework = agent_framework
        self._plugin_framework = plugin_framework
        self._workflows: dict[str, WorkflowDefinition] = {}

    def register_workflow(self, definition: WorkflowDefinition) -> None:
        if not definition.name.strip():
            raise WorkflowEngineError("Workflow name cannot be empty.")
        self._workflows[definition.name] = definition

    def list_workflows(self) -> list[dict[str, Any]]:
        return [
            workflow.as_dict()
            for workflow in sorted(self._workflows.values(), key=lambda item: item.name)
        ]

    async def run_workflow(
        self,
        *,
        workflow_name: str,
        payload: dict[str, Any],
        context: WorkflowExecutionContext,
    ) -> dict[str, Any]:
        workflow = self._workflows.get(workflow_name)
        if workflow is None:
            raise WorkflowEngineError(f"Unknown workflow '{workflow_name}'.", status_code=404)
        await self._event_bus.publish(
            "workflow.started",
            {
                "workflow": workflow.name,
                "version": workflow.version,
                "request_id": context.request_id,
                "actor": context.actor,
            },
            source="workflow-engine",
        )
        step_results: list[dict[str, Any]] = []
        for step in workflow.steps:
            await self._plugin_framework.emit_extension_point(
                "workflow.before_step",
                {
                    "workflow": workflow.name,
                    "step": step.as_dict(),
                    "request_id": context.request_id,
                },
            )
            result = await self._execute_step(
                workflow=workflow,
                step=step,
                payload=payload,
                context=context,
            )
            step_results.append(
                {
                    "id": step.id,
                    "kind": step.kind,
                    "target": step.target,
                    "result": result,
                }
            )
            await self._plugin_framework.emit_extension_point(
                "workflow.after_step",
                {
                    "workflow": workflow.name,
                    "step": step.as_dict(),
                    "request_id": context.request_id,
                    "result": result,
                },
            )
        result_payload = {
            "workflow": workflow.name,
            "version": workflow.version,
            "request_id": context.request_id,
            "steps": step_results,
        }
        await self._event_bus.publish(
            "workflow.completed",
            result_payload,
            source="workflow-engine",
        )
        return result_payload

    async def _execute_step(
        self,
        *,
        workflow: WorkflowDefinition,
        step: WorkflowStep,
        payload: dict[str, Any],
        context: WorkflowExecutionContext,
    ) -> dict[str, Any]:
        if step.kind == "event":
            envelope = await self._event_bus.publish(
                step.target,
                {**payload, **step.config},
                source=f"workflow:{workflow.name}",
            )
            return {"status": "published", "event_id": envelope.id, "topic": envelope.topic}
        if step.kind == "agent":
            return await self._agent_framework.run_agent(
                agent_name=step.target,
                payload={**payload, **step.config},
                context=AgentContext(
                    actor=context.actor,
                    role=context.role,
                    request_id=context.request_id,
                    git_provider=context.git_provider,
                    oauth_owner=context.oauth_owner,
                    metadata=context.metadata,
                ),
            )
        if step.kind == "plugin":
            args = step.config.get("args", [])
            if not isinstance(args, list):
                raise WorkflowEngineError("Workflow plugin step args must be a list.")
            permission = str(
                step.config.get("required_permission", PluginPermissions.EXECUTE)
            )
            return await self._plugin_framework.run_plugin(
                plugin_name=step.target,
                args=[str(item) for item in args],
                context=PluginExecutionContext(
                    actor=context.actor,
                    role=context.role,
                    request_id=context.request_id,
                    git_provider=context.git_provider,
                    metadata=context.metadata,
                ),
                required_permission=permission,
            )
        if step.kind == "noop":
            return {"status": "skipped"}
        raise WorkflowEngineError(f"Unsupported workflow step kind '{step.kind}'.")
