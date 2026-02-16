from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Protocol, runtime_checkable


@dataclass(frozen=True)
class PluginDescriptor:
    name: str
    version: str
    permissions: set[str] = field(default_factory=set)
    extension_points: set[str] = field(default_factory=set)
    runtime: str = "sdk"
    description: str = ""


@dataclass
class PluginContext:
    actor: str
    role: str
    request_id: str
    git_provider: str
    metadata: dict[str, Any] = field(default_factory=dict)


@runtime_checkable
class SDKPlugin(Protocol):
    descriptor: PluginDescriptor

    async def execute(self, context: PluginContext, args: list[str]) -> dict[str, Any]:
        raise NotImplementedError


class BaseSDKPlugin:
    descriptor = PluginDescriptor(name="base-plugin", version="0.0.0")

    async def execute(self, context: PluginContext, args: list[str]) -> dict[str, Any]:
        raise NotImplementedError("Plugins must implement execute().")
