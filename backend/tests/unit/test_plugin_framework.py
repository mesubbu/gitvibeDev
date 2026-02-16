from __future__ import annotations

import pytest

from app.platform.event_bus import AsyncEventBus
from app.platform.plugin_framework import (
    PluginExecutionContext,
    PluginFramework,
    PluginFrameworkError,
    PluginPermissions,
)
from app.platform.plugin_sdk import BaseSDKPlugin, PluginDescriptor


pytestmark = [pytest.mark.unit, pytest.mark.asyncio]


class EchoSDKPlugin(BaseSDKPlugin):
    descriptor = PluginDescriptor(
        name="echo-sdk",
        version="1.2.3",
        permissions={PluginPermissions.EXECUTE},
        extension_points={"plugin.post_execute"},
        runtime="sdk",
    )

    async def execute(self, context, args):
        return {
            "status": "ok",
            "return_code": 0,
            "stdout": " ".join(args),
            "stderr": "",
            "actor": context.actor,
        }


async def test_sdk_plugin_execution_uses_manifest_and_permission() -> None:
    bus = AsyncEventBus()
    framework = PluginFramework(
        event_bus=bus,
        plugins_root="/tmp/missing",
        legacy_executor=None,
        legacy_allowlist=set(),
    )
    framework.register_sdk_plugin(EchoSDKPlugin())

    result = await framework.run_plugin(
        plugin_name="echo-sdk",
        args=["hello", "world"],
        context=PluginExecutionContext(
            actor="alice",
            role="admin",
            request_id="req-1",
            git_provider="github",
        ),
    )

    assert result["runtime"] == "sdk"
    assert result["version"] == "1.2.3"
    assert result["stdout"] == "hello world"
    assert result["actor"] == "alice"


async def test_legacy_plugin_allowlist_compatibility() -> None:
    bus = AsyncEventBus()
    framework = PluginFramework(
        event_bus=bus,
        plugins_root="/tmp/missing",
        legacy_executor=lambda name, args: {
            "status": "ok",
            "return_code": 0,
            "stdout": f"{name}:{len(args)}",
            "stderr": "",
        },
        legacy_allowlist={"legacy-one"},
    )

    result = await framework.run_plugin(
        plugin_name="legacy-one",
        args=["a", "b"],
        context=PluginExecutionContext(
            actor="demo",
            role="admin",
            request_id="req-legacy",
            git_provider="github",
        ),
    )

    assert result["runtime"] == "legacy"
    assert result["stdout"] == "legacy-one:2"


async def test_permission_denied_for_missing_manifest_permission() -> None:
    bus = AsyncEventBus()
    framework = PluginFramework(
        event_bus=bus,
        plugins_root="/tmp/missing",
        legacy_executor=None,
        legacy_allowlist=set(),
    )
    framework.register_sdk_plugin(EchoSDKPlugin())

    with pytest.raises(PluginFrameworkError) as exc:
        await framework.run_plugin(
            plugin_name="echo-sdk",
            args=[],
            context=PluginExecutionContext(
                actor="alice",
                role="admin",
                request_id="req-2",
                git_provider="github",
            ),
            required_permission=PluginPermissions.WRITE_REPO,
        )

    assert exc.value.status_code == 403
