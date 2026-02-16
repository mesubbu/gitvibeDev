from __future__ import annotations

import os
import re
import resource
import subprocess
import tempfile
from pathlib import Path
from typing import Any


PLUGIN_NAME_PATTERN = re.compile(r"^[a-zA-Z0-9._-]+$")


class PluginSandboxError(RuntimeError):
    """Raised when plugin execution is blocked or fails validation."""


class PluginSandbox:
    """Best-effort local plugin isolation with strict default deny behavior."""

    def __init__(
        self,
        *,
        enabled: bool,
        allowlist: set[str],
        plugins_root: str = "/app/plugins",
        timeout_seconds: int = 5,
    ) -> None:
        self._enabled = enabled
        self._allowlist = allowlist
        self._plugins_root = Path(plugins_root).resolve()
        self._timeout_seconds = timeout_seconds

    @staticmethod
    def _limit_resources() -> None:
        resource.setrlimit(resource.RLIMIT_CPU, (2, 2))
        resource.setrlimit(resource.RLIMIT_AS, (256 * 1024 * 1024, 256 * 1024 * 1024))
        resource.setrlimit(resource.RLIMIT_FSIZE, (10 * 1024 * 1024, 10 * 1024 * 1024))
        resource.setrlimit(resource.RLIMIT_NOFILE, (64, 64))
        resource.setrlimit(resource.RLIMIT_NPROC, (32, 32))

    def execute(self, plugin_name: str, args: list[str]) -> dict[str, Any]:
        if not self._enabled:
            raise PluginSandboxError("Plugin sandbox is disabled by default.")
        if plugin_name not in self._allowlist:
            raise PluginSandboxError("Plugin is not in the allowlist.")
        if not PLUGIN_NAME_PATTERN.fullmatch(plugin_name):
            raise PluginSandboxError("Invalid plugin name.")

        plugin_path = (self._plugins_root / plugin_name).resolve()
        if self._plugins_root not in plugin_path.parents:
            raise PluginSandboxError("Plugin path escapes sandbox root.")
        if not plugin_path.exists() or not plugin_path.is_file():
            raise PluginSandboxError("Plugin binary not found.")
        if not os.access(plugin_path, os.X_OK):
            raise PluginSandboxError("Plugin is not executable.")
        if any("\n" in item or "\r" in item for item in args):
            raise PluginSandboxError("Invalid plugin arguments.")

        with tempfile.TemporaryDirectory() as working_dir:
            try:
                proc = subprocess.run(
                    [str(plugin_path), *args],
                    cwd=working_dir,
                    capture_output=True,
                    text=True,
                    env={
                        "PATH": "/usr/bin:/bin",
                        "HOME": working_dir,
                        "TMPDIR": working_dir,
                    },
                    timeout=self._timeout_seconds,
                    preexec_fn=self._limit_resources,
                    shell=False,
                    check=False,
                )
            except subprocess.TimeoutExpired as exc:
                raise PluginSandboxError("Plugin execution timed out.") from exc

        return {
            "status": "ok" if proc.returncode == 0 else "error",
            "return_code": proc.returncode,
            "stdout": proc.stdout[-4096:],
            "stderr": proc.stderr[-4096:],
        }
