from __future__ import annotations

import base64
import hashlib
import json
import logging
import os
from pathlib import Path
from threading import Lock
from typing import Any

from cryptography.fernet import Fernet, InvalidToken

LOGGER = logging.getLogger("gitvibedev.vault")


class VaultError(RuntimeError):
    """Raised when vault data cannot be read or written safely."""


def _derive_fernet_key(master_key: str) -> bytes:
    digest = hashlib.sha256(master_key.encode("utf-8")).digest()
    return base64.urlsafe_b64encode(digest)


class LocalVault:
    """Encrypted local vault for tokens and security metadata."""

    def __init__(self, file_path: str, master_key: str) -> None:
        self._path = Path(file_path)
        self._lock = Lock()
        self._fernet = Fernet(_derive_fernet_key(master_key))
        self._ensure_storage()

    def _ensure_storage(self) -> None:
        self._path.parent.mkdir(parents=True, exist_ok=True)
        try:
            os.chmod(self._path.parent, 0o700)
        except PermissionError:
            LOGGER.warning("Could not set vault directory permissions to 0700.")
        if not self._path.exists():
            self._write_unlocked({})
        try:
            os.chmod(self._path, 0o600)
        except PermissionError:
            LOGGER.warning("Could not set vault file permissions to 0600.")

    def _read_unlocked(self) -> dict[str, Any]:
        if not self._path.exists():
            return {}
        ciphertext = self._path.read_bytes()
        if not ciphertext:
            return {}
        try:
            plaintext = self._fernet.decrypt(ciphertext)
        except InvalidToken as exc:
            raise VaultError("Vault decryption failed. Invalid master key.") from exc
        try:
            loaded = json.loads(plaintext.decode("utf-8"))
        except json.JSONDecodeError as exc:
            raise VaultError("Vault payload is corrupted.") from exc
        if not isinstance(loaded, dict):
            raise VaultError("Vault payload must be a JSON object.")
        return loaded

    def _write_unlocked(self, payload: dict[str, Any]) -> None:
        encoded = json.dumps(payload, separators=(",", ":"), sort_keys=True).encode("utf-8")
        ciphertext = self._fernet.encrypt(encoded)
        self._path.write_bytes(ciphertext)
        try:
            os.chmod(self._path, 0o600)
        except PermissionError:
            LOGGER.warning("Could not enforce vault file permissions to 0600.")

    def get(self, key: str, default: Any = None) -> Any:
        with self._lock:
            data = self._read_unlocked()
            return data.get(key, default)

    def set(self, key: str, value: Any) -> None:
        with self._lock:
            data = self._read_unlocked()
            data[key] = value
            self._write_unlocked(data)

    def delete(self, key: str) -> None:
        with self._lock:
            data = self._read_unlocked()
            if key in data:
                del data[key]
                self._write_unlocked(data)

    def rotate_master_key(self, new_master_key: str) -> None:
        with self._lock:
            data = self._read_unlocked()
            self._fernet = Fernet(_derive_fernet_key(new_master_key))
            self._write_unlocked(data)
