from __future__ import annotations

import hashlib
import json
import logging
import os
import secrets
import time
import uuid
from collections import defaultdict, deque
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

import jwt
from fastapi import HTTPException, Request, status
from jwt import ExpiredSignatureError, InvalidTokenError
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse

from .vault import LocalVault

ROLE_LEVELS: dict[str, int] = {"viewer": 10, "operator": 20, "admin": 30}


def env_bool(name: str, default: bool = False) -> bool:
    value = os.getenv(name)
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


def env_int(name: str, default: int) -> int:
    raw_value = os.getenv(name)
    if raw_value is None:
        return default
    try:
        return int(raw_value)
    except ValueError:
        return default


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


@dataclass(frozen=True)
class SecurityConfig:
    secret_key: str
    bootstrap_admin_token: str
    access_token_ttl_minutes: int
    refresh_token_ttl_hours: int
    token_max_previous_keys: int
    rate_limit_per_minute: int
    rate_limit_burst: int
    max_request_body_bytes: int
    csrf_protection_enabled: bool
    security_headers_enabled: bool
    audit_log_file: str
    vault_file: str

    @staticmethod
    def from_env() -> SecurityConfig:
        return SecurityConfig(
            secret_key=os.getenv("SECRET_KEY", "change_me"),
            bootstrap_admin_token=os.getenv("BOOTSTRAP_ADMIN_TOKEN", "change_me"),
            access_token_ttl_minutes=env_int("ACCESS_TOKEN_TTL_MINUTES", 20),
            refresh_token_ttl_hours=env_int("REFRESH_TOKEN_TTL_HOURS", 12),
            token_max_previous_keys=max(1, env_int("TOKEN_MAX_PREVIOUS_KEYS", 2)),
            rate_limit_per_minute=max(20, env_int("RATE_LIMIT_PER_MINUTE", 120)),
            rate_limit_burst=max(0, env_int("RATE_LIMIT_BURST", 30)),
            max_request_body_bytes=max(1024, env_int("MAX_REQUEST_BODY_BYTES", 1_048_576)),
            csrf_protection_enabled=env_bool("CSRF_PROTECTION_ENABLED", True),
            security_headers_enabled=env_bool("SECURITY_HEADERS_ENABLED", True),
            audit_log_file=os.getenv("AUDIT_LOG_FILE", "/data/logs/audit.log"),
            vault_file=os.getenv("VAULT_FILE", "/data/vault/secrets.enc"),
        )


@dataclass(frozen=True)
class AuthContext:
    subject: str
    role: str
    csrf_token: str
    token_id: str


class AuditLogger:
    """JSON-lines security and request audit logger."""

    def __init__(self, file_path: str) -> None:
        self._file_path = Path(file_path)
        self._file_path.parent.mkdir(parents=True, exist_ok=True)
        try:
            os.chmod(self._file_path.parent, 0o700)
        except PermissionError:
            logging.getLogger("gitvibedev.audit").warning(
                "Could not set audit directory permissions to 0700."
            )
        if not self._file_path.exists():
            self._file_path.touch()
        try:
            os.chmod(self._file_path, 0o600)
        except PermissionError:
            logging.getLogger("gitvibedev.audit").warning(
                "Could not set audit file permissions to 0600."
            )
        self._logger = logging.getLogger("gitvibedev.audit")

    def _emit(self, payload: dict[str, Any]) -> None:
        line = json.dumps(payload, separators=(",", ":"), sort_keys=True)
        self._logger.info(line)
        with self._file_path.open("a", encoding="utf-8") as handle:
            handle.write(f"{line}\n")

    def request(
        self,
        *,
        request_id: str,
        method: str,
        path: str,
        status_code: int,
        duration_ms: int,
        ip: str,
        user_agent: str,
        actor: str,
    ) -> None:
        self._emit(
            {
                "event": "request",
                "timestamp": utc_now().isoformat(),
                "request_id": request_id,
                "method": method,
                "path": path,
                "status_code": status_code,
                "duration_ms": duration_ms,
                "ip": ip,
                "user_agent": user_agent,
                "actor": actor,
            }
        )

    def security(self, event: str, actor: str, details: dict[str, Any]) -> None:
        payload = {
            "event": event,
            "timestamp": utc_now().isoformat(),
            "actor": actor,
            "details": details,
        }
        self._emit(payload)


class TokenService:
    """JWT issuing, verification, and refresh-token rotation service."""

    SIGNING_STATE_KEY = "jwt_signing_state"
    REFRESH_STATE_KEY = "refresh_sessions"

    def __init__(self, config: SecurityConfig, vault: LocalVault) -> None:
        self._config = config
        self._vault = vault
        self._signing_state = self._load_signing_state()

    def _load_signing_state(self) -> dict[str, Any]:
        loaded = self._vault.get(self.SIGNING_STATE_KEY)
        if isinstance(loaded, dict) and "current" in loaded and "previous" in loaded:
            return loaded
        state = {
            "current": {"kid": "initial", "key": self._config.secret_key},
            "previous": [],
        }
        self._vault.set(self.SIGNING_STATE_KEY, state)
        return state

    def _persist_signing_state(self) -> None:
        self._vault.set(self.SIGNING_STATE_KEY, self._signing_state)

    def _signing_keys_by_id(self) -> dict[str, str]:
        keys = {
            self._signing_state["current"]["kid"]: self._signing_state["current"]["key"],
        }
        for item in self._signing_state["previous"]:
            keys[item["kid"]] = item["key"]
        return keys

    @staticmethod
    def _hash_token(raw_token: str) -> str:
        return hashlib.sha256(raw_token.encode("utf-8")).hexdigest()

    def _load_refresh_sessions(self) -> dict[str, dict[str, Any]]:
        raw = self._vault.get(self.REFRESH_STATE_KEY, {})
        sessions = raw if isinstance(raw, dict) else {}
        current_ts = int(utc_now().timestamp())
        filtered = {
            token_hash: details
            for token_hash, details in sessions.items()
            if isinstance(details, dict) and int(details.get("expires_at", 0)) > current_ts
        }
        if filtered != sessions:
            self._vault.set(self.REFRESH_STATE_KEY, filtered)
        return filtered

    def _save_refresh_sessions(self, sessions: dict[str, dict[str, Any]]) -> None:
        self._vault.set(self.REFRESH_STATE_KEY, sessions)

    def issue_token_pair(self, *, subject: str, role: str) -> dict[str, Any]:
        if role not in ROLE_LEVELS:
            raise HTTPException(status_code=400, detail="Invalid role.")
        now = utc_now()
        csrf_token = secrets.token_urlsafe(24)
        access_exp = now + timedelta(minutes=self._config.access_token_ttl_minutes)
        refresh_exp = now + timedelta(hours=self._config.refresh_token_ttl_hours)
        token_id = str(uuid.uuid4())
        refresh_id = str(uuid.uuid4())
        kid = self._signing_state["current"]["kid"]
        signing_key = self._signing_state["current"]["key"]

        access_payload = {
            "sub": subject,
            "role": role,
            "type": "access",
            "csrf": csrf_token,
            "jti": token_id,
            "iat": int(now.timestamp()),
            "exp": int(access_exp.timestamp()),
        }
        refresh_payload = {
            "sub": subject,
            "role": role,
            "type": "refresh",
            "jti": refresh_id,
            "iat": int(now.timestamp()),
            "exp": int(refresh_exp.timestamp()),
        }

        access_token = jwt.encode(
            access_payload,
            signing_key,
            algorithm="HS256",
            headers={"kid": kid},
        )
        refresh_token = jwt.encode(
            refresh_payload,
            signing_key,
            algorithm="HS256",
            headers={"kid": kid},
        )

        sessions = self._load_refresh_sessions()
        sessions[self._hash_token(refresh_token)] = {
            "subject": subject,
            "role": role,
            "expires_at": int(refresh_exp.timestamp()),
        }
        self._save_refresh_sessions(sessions)
        return {
            "access_token": access_token,
            "refresh_token": refresh_token,
            "token_type": "bearer",
            "expires_in": int((access_exp - now).total_seconds()),
            "csrf_token": csrf_token,
            "role": role,
        }

    def _decode_token(self, raw_token: str, expected_type: str) -> dict[str, Any]:
        try:
            header = jwt.get_unverified_header(raw_token)
        except InvalidTokenError as exc:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED, detail="Malformed token header."
            ) from exc

        keys = self._signing_keys_by_id()
        key_id = header.get("kid")
        candidate_keys: list[str] = []
        if isinstance(key_id, str) and key_id in keys:
            candidate_keys.append(keys[key_id])
        candidate_keys.extend(value for _, value in keys.items() if value not in candidate_keys)

        for key in candidate_keys:
            try:
                payload = jwt.decode(raw_token, key, algorithms=["HS256"])
            except ExpiredSignatureError as exc:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED, detail="Token expired."
                ) from exc
            except InvalidTokenError:
                continue
            token_type = payload.get("type")
            if token_type != expected_type:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Unexpected token type.",
                )
            return payload
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token.")

    def verify_access_token(self, raw_token: str) -> AuthContext:
        payload = self._decode_token(raw_token, expected_type="access")
        subject = payload.get("sub")
        role = payload.get("role")
        csrf_token = payload.get("csrf")
        token_id = payload.get("jti")
        if not all(
            isinstance(value, str) and value
            for value in [subject, role, csrf_token, token_id]
        ):
            raise HTTPException(status_code=401, detail="Invalid access token payload.")
        if role not in ROLE_LEVELS:
            raise HTTPException(status_code=401, detail="Unknown role in token.")
        return AuthContext(
            subject=subject,
            role=role,
            csrf_token=csrf_token,
            token_id=token_id,
        )

    def rotate_refresh_token(self, refresh_token: str) -> dict[str, Any]:
        payload = self._decode_token(refresh_token, expected_type="refresh")
        token_hash = self._hash_token(refresh_token)
        sessions = self._load_refresh_sessions()
        existing = sessions.pop(token_hash, None)
        if existing is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Refresh token is invalid or already rotated.",
            )
        self._save_refresh_sessions(sessions)
        return self.issue_token_pair(
            subject=str(payload["sub"]),
            role=str(payload["role"]),
        )

    def rotate_signing_key(self) -> str:
        previous_keys: list[dict[str, str]] = self._signing_state["previous"]
        previous_keys.insert(0, self._signing_state["current"])
        self._signing_state["previous"] = previous_keys[
            : self._config.token_max_previous_keys
        ]
        self._signing_state["current"] = {
            "kid": str(uuid.uuid4()),
            "key": secrets.token_urlsafe(64),
        }
        self._persist_signing_state()
        return str(self._signing_state["current"]["kid"])


class PayloadSizeMiddleware(BaseHTTPMiddleware):
    def __init__(self, app: Any, max_bytes: int) -> None:
        super().__init__(app)
        self._max_bytes = max_bytes

    async def dispatch(self, request: Request, call_next: Any) -> JSONResponse:
        content_length = request.headers.get("content-length")
        if content_length:
            try:
                parsed_length = int(content_length)
            except ValueError:
                return JSONResponse(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    content={"detail": "Invalid Content-Length header."},
                )
            if parsed_length > self._max_bytes:
                return JSONResponse(
                    status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                    content={"detail": "Request payload too large."},
                )
        return await call_next(request)


class RateLimitMiddleware(BaseHTTPMiddleware):
    def __init__(
        self,
        app: Any,
        *,
        rate_limit_per_minute: int,
        burst: int,
        audit_logger: AuditLogger,
    ) -> None:
        super().__init__(app)
        self._rate_limit_per_minute = rate_limit_per_minute
        self._burst = burst
        self._audit_logger = audit_logger
        self._requests: dict[str, deque[float]] = defaultdict(deque)

    async def dispatch(self, request: Request, call_next: Any) -> JSONResponse:
        now = time.monotonic()
        ip = request.client.host if request.client else "unknown"
        key = ip
        bucket = self._requests[key]
        while bucket and (now - bucket[0]) > 60:
            bucket.popleft()

        limit = self._rate_limit_per_minute + self._burst
        if request.url.path.startswith("/api/auth/"):
            limit = max(10, self._rate_limit_per_minute // 4)

        if len(bucket) >= limit:
            retry_after = max(1, int(60 - (now - bucket[0])))
            self._audit_logger.security(
                "rate_limit_exceeded",
                actor=ip,
                details={"path": request.url.path, "limit": limit},
            )
            return JSONResponse(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                headers={"Retry-After": str(retry_after)},
                content={"detail": "Rate limit exceeded."},
            )

        bucket.append(now)
        return await call_next(request)


class SecureHeadersMiddleware(BaseHTTPMiddleware):
    def __init__(self, app: Any, enabled: bool) -> None:
        super().__init__(app)
        self._enabled = enabled

    async def dispatch(self, request: Request, call_next: Any) -> JSONResponse:
        response = await call_next(request)
        if not self._enabled:
            return response
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["Referrer-Policy"] = "no-referrer"
        response.headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()"
        response.headers["X-XSS-Protection"] = "0"
        response.headers["Content-Security-Policy"] = (
            "default-src 'self'; frame-ancestors 'none'; base-uri 'self'; "
            "object-src 'none'; form-action 'self'"
        )
        response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
        return response


class AuditLogMiddleware(BaseHTTPMiddleware):
    def __init__(self, app: Any, audit_logger: AuditLogger) -> None:
        super().__init__(app)
        self._audit_logger = audit_logger

    async def dispatch(self, request: Request, call_next: Any) -> JSONResponse:
        started = time.monotonic()
        request_id = request.headers.get("x-request-id", str(uuid.uuid4()))
        response = await call_next(request)
        duration_ms = int((time.monotonic() - started) * 1000)
        actor = getattr(request.state, "auth_subject", "anonymous")
        user_agent = request.headers.get("user-agent", "")
        ip = request.client.host if request.client else "unknown"
        self._audit_logger.request(
            request_id=request_id,
            method=request.method,
            path=request.url.path,
            status_code=response.status_code,
            duration_ms=duration_ms,
            ip=ip,
            user_agent=user_agent,
            actor=actor,
        )
        response.headers["X-Request-ID"] = request_id
        return response
