from __future__ import annotations

import asyncio
import json
import re
import uuid
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Callable

from .event_bus import AsyncEventBus
from .plugin_sdk import PluginContext, PluginDescriptor, SDKPlugin

SEMVER_PATTERN = re.compile(r"^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$")
PluginLegacyExecutor = Callable[[str, list[str]], dict[str, Any]]
PluginHook = Callable[[dict[str, Any]], Any]


class PluginPermissions:
    EXECUTE = "plugin:execute"
    READ_REPO = "repo:read"
    WRITE_REPO = "repo:write"
    WORKFLOW_RUN = "workflow:run"
    EVENT_PUBLISH = "event:publish"


class PluginFrameworkError(RuntimeError):
    def __init__(self, message: str, *, status_code: int = 400) -> None:
        super().__init__(message)
        self.status_code = status_code


@dataclass(frozen=True)
class PluginManifest:
    name: str
    version: str
    runtime: str = "process"
    description: str = ""
    permissions: set[str] = field(default_factory=set)
    extension_points: set[str] = field(default_factory=set)
    git_providers: set[str] = field(default_factory=lambda: {"github"})
    entrypoint: str | None = None

    def to_dict(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "version": self.version,
            "runtime": self.runtime,
            "description": self.description,
            "permissions": sorted(self.permissions),
            "extension_points": sorted(self.extension_points),
            "git_providers": sorted(self.git_providers),
            "entrypoint": self.entrypoint,
        }

    @staticmethod
    def from_dict(payload: dict[str, Any]) -> "PluginManifest":
        return PluginManifest(
            name=str(payload["name"]),
            version=str(payload.get("version", "0.1.0")),
            runtime=str(payload.get("runtime", "process")),
            description=str(payload.get("description", "")),
            permissions={
                str(item)
                for item in payload.get("permissions", [PluginPermissions.EXECUTE])
            },
            extension_points={str(item) for item in payload.get("extension_points", [])},
            git_providers={
                str(item) for item in payload.get("git_providers", ["github"])
            },
            entrypoint=(
                str(payload.get("entrypoint"))
                if payload.get("entrypoint") is not None
                else None
            ),
        )


@dataclass(frozen=True)
class PluginExecutionContext:
    actor: str
    role: str
    request_id: str
    git_provider: str
    metadata: dict[str, Any] = field(default_factory=dict)


class PluginRegistry:
    def __init__(self) -> None:
        self._manifests: dict[str, PluginManifest] = {}
        self._sdk_plugins: dict[str, SDKPlugin] = {}

    @staticmethod
    def _validate_manifest(manifest: PluginManifest) -> None:
        if not manifest.name.strip():
            raise PluginFrameworkError("Plugin name cannot be empty.")
        if not SEMVER_PATTERN.fullmatch(manifest.version):
            raise PluginFrameworkError(
                f"Plugin '{manifest.name}' version must be semver-like.",
            )

    def register_manifest(self, manifest: PluginManifest, *, replace: bool = True) -> None:
        self._validate_manifest(manifest)
        if not replace and manifest.name in self._manifests:
            return
        self._manifests[manifest.name] = manifest

    def register_sdk_plugin(self, plugin: SDKPlugin) -> None:
        descriptor = plugin.descriptor
        manifest = PluginManifest(
            name=descriptor.name,
            version=descriptor.version,
            runtime=descriptor.runtime,
            description=descriptor.description,
            permissions=set(descriptor.permissions),
            extension_points=set(descriptor.extension_points),
            git_providers={"github", "gitlab", "gitea", "bitbucket"},
            entrypoint=f"sdk://{descriptor.name}",
        )
        self.register_manifest(manifest)
        self._sdk_plugins[manifest.name] = plugin

    def discover_manifests(self, plugins_root: str) -> int:
        root = Path(plugins_root)
        if not root.exists():
            return 0
        loaded = 0
        patterns = ("*.plugin.json", "*/plugin.json")
        for pattern in patterns:
            for candidate in root.glob(pattern):
                try:
                    payload = json.loads(candidate.read_text(encoding="utf-8"))
                except (OSError, json.JSONDecodeError):
                    continue
                if not isinstance(payload, dict):
                    continue
                try:
                    manifest = PluginManifest.from_dict(payload)
                    self.register_manifest(manifest)
                except PluginFrameworkError:
                    continue
                loaded += 1
        return loaded

    def get_manifest(self, name: str) -> PluginManifest | None:
        return self._manifests.get(name)

    def get_sdk_plugin(self, name: str) -> SDKPlugin | None:
        return self._sdk_plugins.get(name)

    def list_manifests(self) -> list[dict[str, Any]]:
        return [manifest.to_dict() for manifest in sorted(self._manifests.values(), key=lambda item: item.name)]


class PluginFramework:
    def __init__(
        self,
        *,
        event_bus: AsyncEventBus,
        plugins_root: str,
        legacy_executor: PluginLegacyExecutor | None,
        legacy_allowlist: set[str],
    ) -> None:
        self._event_bus = event_bus
        self._registry = PluginRegistry()
        self._plugins_root = plugins_root
        self._legacy_executor = legacy_executor
        self._legacy_allowlist = legacy_allowlist
        self._hooks: dict[str, list[PluginHook]] = {}
        self._extension_points: dict[str, str] = {}
        self._register_builtin_extension_points()
        self._registry.discover_manifests(self._plugins_root)

    def _register_builtin_extension_points(self) -> None:
        self.register_extension_point("plugin.pre_execute", "Runs before plugin execution.")
        self.register_extension_point("plugin.post_execute", "Runs after plugin execution.")
        self.register_extension_point("workflow.before_step", "Runs before workflow step execution.")
        self.register_extension_point("workflow.after_step", "Runs after workflow step execution.")

    def register_extension_point(self, name: str, description: str) -> None:
        self._extension_points[name] = description

    def list_extension_points(self) -> list[dict[str, str]]:
        return [
            {"name": key, "description": value}
            for key, value in sorted(self._extension_points.items())
        ]

    def register_hook(self, extension_point: str, callback: PluginHook) -> None:
        if extension_point not in self._extension_points:
            raise PluginFrameworkError(
                f"Unknown extension point: {extension_point}",
                status_code=404,
            )
        self._hooks.setdefault(extension_point, []).append(callback)

    async def emit_extension_point(self, extension_point: str, payload: dict[str, Any]) -> None:
        callbacks = self._hooks.get(extension_point, [])
        for callback in callbacks:
            maybe_coro = callback(payload)
            if asyncio.iscoroutine(maybe_coro):
                await maybe_coro

    def register_sdk_plugin(self, plugin: SDKPlugin) -> None:
        self._registry.register_sdk_plugin(plugin)

    def get_plugin_manifest(self, name: str) -> dict[str, Any] | None:
        manifest = self._registry.get_manifest(name)
        if manifest is None:
            return None
        return manifest.to_dict()

    def list_plugins(self) -> list[dict[str, Any]]:
        return self._registry.list_manifests()

    def _legacy_manifest(self, plugin_name: str) -> PluginManifest:
        return PluginManifest(
            name=plugin_name,
            version="0.1.0-legacy",
            runtime="legacy",
            description="Auto-registered legacy plugin.",
            permissions={PluginPermissions.EXECUTE},
            extension_points={"plugin.pre_execute", "plugin.post_execute"},
            git_providers={"github"},
            entrypoint=f"{self._plugins_root}/{plugin_name}",
        )

    def _resolve_manifest(self, plugin_name: str) -> PluginManifest:
        manifest = self._registry.get_manifest(plugin_name)
        if manifest is not None:
            return manifest
        if plugin_name in self._legacy_allowlist:
            legacy = self._legacy_manifest(plugin_name)
            self._registry.register_manifest(legacy, replace=False)
            return legacy
        raise PluginFrameworkError(
            f"Plugin '{plugin_name}' is not registered.",
            status_code=404,
        )

    @staticmethod
    def _ensure_permission(manifest: PluginManifest, required_permission: str) -> None:
        if required_permission not in manifest.permissions:
            raise PluginFrameworkError(
                (
                    f"Plugin '{manifest.name}' (version {manifest.version}) "
                    f"does not grant permission '{required_permission}'."
                ),
                status_code=403,
            )

    async def run_plugin(
        self,
        *,
        plugin_name: str,
        args: list[str],
        context: PluginExecutionContext,
        required_permission: str = PluginPermissions.EXECUTE,
    ) -> dict[str, Any]:
        manifest = self._resolve_manifest(plugin_name)
        self._ensure_permission(manifest, required_permission)
        event_payload = {
            "plugin": plugin_name,
            "version": manifest.version,
            "runtime": manifest.runtime,
            "actor": context.actor,
            "request_id": context.request_id,
            "git_provider": context.git_provider,
            "args": args,
        }
        await self._event_bus.publish(
            "plugin.pre_execute",
            event_payload,
            source="plugin-framework",
        )
        await self.emit_extension_point("plugin.pre_execute", event_payload)

        sdk_plugin = self._registry.get_sdk_plugin(plugin_name)
        try:
            if sdk_plugin is not None:
                result = await sdk_plugin.execute(
                    PluginContext(
                        actor=context.actor,
                        role=context.role,
                        request_id=context.request_id,
                        git_provider=context.git_provider,
                        metadata=context.metadata,
                    ),
                    args,
                )
            else:
                if self._legacy_executor is None:
                    raise PluginFrameworkError(
                        "No legacy plugin executor configured.",
                        status_code=503,
                    )
                result = self._legacy_executor(plugin_name, args)
        except PluginFrameworkError:
            raise
        except Exception as exc:
            raise PluginFrameworkError(str(exc), status_code=403) from exc

        final_result = {
            "plugin": manifest.name,
            "version": manifest.version,
            "runtime": manifest.runtime,
            "request_id": context.request_id or str(uuid.uuid4()),
            **result,
        }
        await self._event_bus.publish(
            "plugin.post_execute",
            {**event_payload, "result_status": final_result.get("status", "unknown")},
            source="plugin-framework",
        )
        await self.emit_extension_point(
            "plugin.post_execute",
            {**event_payload, "result": final_result},
        )
        return final_result
