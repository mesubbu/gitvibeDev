from __future__ import annotations

import asyncio
import os
import secrets
from hashlib import sha256
from typing import Any

import asyncpg
from fastapi import Depends, FastAPI, Header, HTTPException, Query, Request, status
from fastapi.responses import JSONResponse
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, Field
from redis.asyncio import Redis
from redis.exceptions import RedisError

from .ai_service import AIProviderError, AIReviewRequestContext, AIReviewService
from .demo_service import DemoDataService
from .github_service import GitHubConfig, GitHubService
from .job_queue import PersistentJobQueue
from .plugin_sandbox import PluginSandbox, PluginSandboxError
from .security import (
    ROLE_LEVELS,
    AuditLogMiddleware,
    AuditLogger,
    AuthContext,
    PayloadSizeMiddleware,
    RateLimitMiddleware,
    SecureHeadersMiddleware,
    SecurityConfig,
    TokenService,
    env_bool,
    env_int,
)
from .vault import LocalVault


DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://gitvibe:postgres_change_me@postgres:5432/gitvibe",
)
REDIS_URL = os.getenv("REDIS_URL", "redis://:redis_change_me@redis:6379/0")
OLLAMA_BASE_URL = os.getenv("OLLAMA_BASE_URL", "http://ollama:11434")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "llama3.2")
AI_PROVIDER = os.getenv("AI_PROVIDER", "ollama")
OPENAI_BASE_URL = os.getenv("OPENAI_BASE_URL", "https://api.openai.com/v1")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")
OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-4o-mini")
DEMO_MODE = env_bool("DEMO_MODE", True)
GITHUB_APP_CLIENT_ID = os.getenv("GITHUB_APP_CLIENT_ID", "")
GITHUB_APP_CLIENT_SECRET = os.getenv("GITHUB_APP_CLIENT_SECRET", "")
GITHUB_APP_PRIVATE_KEY = os.getenv("GITHUB_APP_PRIVATE_KEY", "")
GITHUB_OAUTH_REDIRECT_URI = os.getenv("GITHUB_OAUTH_REDIRECT_URI", "")
APP_ENCRYPTION_KEY = os.getenv("APP_ENCRYPTION_KEY", "change_me")

security_config = SecurityConfig.from_env()
vault = LocalVault(file_path=security_config.vault_file, master_key=APP_ENCRYPTION_KEY)
audit_logger = AuditLogger(file_path=security_config.audit_log_file)
token_service = TokenService(config=security_config, vault=vault)
plugin_sandbox = PluginSandbox(
    enabled=env_bool("PLUGIN_SANDBOX_ENABLED", False),
    allowlist={
        item.strip()
        for item in os.getenv("PLUGIN_ALLOWLIST", "").split(",")
        if item.strip()
    },
    timeout_seconds=max(1, env_int("PLUGIN_TIMEOUT_SECONDS", 5)),
)
github_service = GitHubService(
    config=GitHubConfig(
        client_id=GITHUB_APP_CLIENT_ID,
        client_secret=GITHUB_APP_CLIENT_SECRET,
        app_private_key=GITHUB_APP_PRIVATE_KEY,
        oauth_redirect_uri=GITHUB_OAUTH_REDIRECT_URI,
    ),
    vault=vault,
    audit_logger=audit_logger,
)
ai_review_service = AIReviewService(
    provider_name=AI_PROVIDER,
    ollama_base_url=OLLAMA_BASE_URL,
    ollama_model=OLLAMA_MODEL,
    openai_base_url=OPENAI_BASE_URL,
    openai_api_key=OPENAI_API_KEY,
    openai_model=OPENAI_MODEL,
)
job_queue = PersistentJobQueue(
    vault=vault,
    audit_logger=audit_logger,
    poll_interval_seconds=max(0, env_int("JOB_QUEUE_POLL_SECONDS", 1)),
    retry_base_seconds=max(1, env_int("JOB_RETRY_BASE_SECONDS", 2)),
)
demo_data = DemoDataService()
app = FastAPI(title="GitVibeDev Backend", version="0.2.0")
bearer = HTTPBearer(auto_error=False)

app.add_middleware(PayloadSizeMiddleware, max_bytes=security_config.max_request_body_bytes)
app.add_middleware(
    RateLimitMiddleware,
    rate_limit_per_minute=security_config.rate_limit_per_minute,
    burst=security_config.rate_limit_burst,
    audit_logger=audit_logger,
)
app.add_middleware(
    SecureHeadersMiddleware,
    enabled=security_config.security_headers_enabled,
)
app.add_middleware(AuditLogMiddleware, audit_logger=audit_logger)

CSRF_EXEMPT_PATHS = {
    "/api/auth/token",
    "/api/auth/refresh",
}


class TokenIssueRequest(BaseModel):
    username: str = Field(min_length=3, max_length=128)
    role: str = Field(default="viewer")


class TokenRefreshRequest(BaseModel):
    refresh_token: str = Field(min_length=16)


class OAuthTokenStoreRequest(BaseModel):
    provider: str = Field(min_length=2, max_length=64)
    owner: str = Field(min_length=2, max_length=128)
    access_token: str = Field(min_length=10)
    expires_at: int | None = None
    scopes: list[str] = Field(default_factory=list)


class PluginRunRequest(BaseModel):
    args: list[str] = Field(default_factory=list, max_length=10)


class MergePullRequestRequest(BaseModel):
    merge_method: str = Field(default="squash", pattern="^(merge|squash|rebase)$")
    commit_title: str | None = Field(default=None, max_length=200)


class CollaboratorUpsertRequest(BaseModel):
    permission: str = Field(default="push", min_length=3, max_length=20)


class AIReviewRequest(BaseModel):
    owner: str = Field(min_length=1, max_length=128)
    repo: str = Field(min_length=1, max_length=128)
    pull_number: int = Field(ge=1)
    oauth_owner: str | None = Field(default=None, max_length=128)
    focus: str | None = Field(default=None, max_length=240)


class AIReviewJobRequest(AIReviewRequest):
    max_retries: int = Field(default=2, ge=0, le=8)


def oauth_vault_key(provider: str, owner: str) -> str:
    return f"oauth::{provider.lower()}::{owner.lower()}"


def resolve_oauth_owner(owner_hint: str | None, context: AuthContext | None) -> str:
    if owner_hint and owner_hint.strip():
        return owner_hint.strip().lower()
    if context is not None:
        return context.subject.lower()
    raise HTTPException(status_code=400, detail="OAuth owner is required.")


def ensure_role(context: AuthContext | None, required_role: str) -> AuthContext:
    if context is None:
        raise HTTPException(status_code=401, detail="Missing bearer token.")
    if ROLE_LEVELS[context.role] < ROLE_LEVELS[required_role]:
        raise HTTPException(status_code=403, detail="Insufficient role for this action.")
    return context


async def build_review_context(
    *,
    owner: str,
    repo: str,
    pull_number: int,
    oauth_owner: str,
    focus: str,
) -> AIReviewRequestContext:
    if DEMO_MODE:
        raw = demo_data.pull_review_context(repo, pull_number)
        if not raw:
            raise HTTPException(status_code=404, detail="Demo pull request not found.")
        resolved_owner = owner or str(raw.get("owner", "demo-org"))
        return AIReviewRequestContext(
            owner=resolved_owner,
            repo=repo,
            pull_number=pull_number,
            title=str(raw.get("title", "")),
            body=str(raw.get("body", "")),
            diff=str(raw.get("diff", "")),
            focus=focus,
        )
    raw = await github_service.get_pull_review_context(
        owner=owner,
        repo=repo,
        pull_number=pull_number,
        oauth_owner=oauth_owner,
    )
    return AIReviewRequestContext(
        owner=owner,
        repo=repo,
        pull_number=pull_number,
        title=str(raw.get("title", "")),
        body=str(raw.get("body", "")),
        diff=str(raw.get("diff", "")),
        focus=focus,
    )


async def run_ai_review_job(payload: dict[str, Any]) -> dict[str, Any]:
    owner = str(payload.get("owner", "")).strip().lower()
    repo = str(payload.get("repo", "")).strip()
    pull_number = int(payload.get("pull_number", 0))
    focus = str(payload.get("focus", "") or "")
    oauth_owner = str(payload.get("oauth_owner", "")).strip().lower()
    if not owner or not repo or pull_number < 1:
        raise ValueError("Invalid AI review job payload.")
    if not DEMO_MODE and not oauth_owner:
        raise ValueError("oauth_owner is required for non-demo AI review jobs.")
    context = await build_review_context(
        owner=owner,
        repo=repo,
        pull_number=pull_number,
        oauth_owner=oauth_owner,
        focus=focus,
    )
    return await ai_review_service.review_pull_request(context)


job_queue.register_handler("ai_review", run_ai_review_job)


@app.on_event("startup")
async def startup_event() -> None:
    if DEMO_MODE:
        demo_data.seed()
    await job_queue.start()


@app.on_event("shutdown")
async def shutdown_event() -> None:
    await job_queue.stop()


async def get_auth_context(
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
) -> AuthContext:
    if credentials is None:
        raise HTTPException(status_code=401, detail="Missing bearer token.")
    context = token_service.verify_access_token(credentials.credentials)
    request.state.auth_subject = context.subject

    csrf_protected_method = request.method.upper() not in {"GET", "HEAD", "OPTIONS"}
    if (
        security_config.csrf_protection_enabled
        and csrf_protected_method
        and request.url.path.startswith("/api/")
        and request.url.path not in CSRF_EXEMPT_PATHS
    ):
        csrf_header = request.headers.get("x-csrf-token", "")
        if not csrf_header or not secrets.compare_digest(csrf_header, context.csrf_token):
            raise HTTPException(status_code=403, detail="CSRF token is missing or invalid.")
    return context


def require_role(required_role: str) -> Any:
    if required_role not in ROLE_LEVELS:
        raise ValueError("Unknown role requested in RBAC policy.")

    async def dependency(context: AuthContext = Depends(get_auth_context)) -> AuthContext:
        if ROLE_LEVELS[context.role] < ROLE_LEVELS[required_role]:
            raise HTTPException(status_code=403, detail="Insufficient role for this action.")
        return context

    return dependency


async def demo_or_viewer_context(
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
) -> AuthContext | None:
    if credentials is None:
        if DEMO_MODE:
            request.state.auth_subject = "demo-anonymous"
            return None
        raise HTTPException(status_code=401, detail="Missing bearer token.")
    context = await get_auth_context(request, credentials)
    if ROLE_LEVELS[context.role] < ROLE_LEVELS["viewer"]:
        raise HTTPException(status_code=403, detail="Viewer role is required.")
    return context


async def optional_auth_context(
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
) -> AuthContext | None:
    if credentials is None:
        return None
    context = token_service.verify_access_token(credentials.credentials)
    request.state.auth_subject = context.subject
    return context


async def check_postgres() -> tuple[bool, str]:
    connection: asyncpg.Connection | None = None
    try:
        connection = await asyncpg.connect(DATABASE_URL, timeout=4)
        await connection.execute("SELECT 1;")
        return True, "ok"
    except (asyncpg.PostgresError, OSError, asyncio.TimeoutError) as exc:
        return False, str(exc)
    finally:
        if connection is not None:
            await connection.close()


async def check_redis() -> tuple[bool, str]:
    client = Redis.from_url(REDIS_URL, socket_connect_timeout=4, socket_timeout=4)
    try:
        await client.ping()
        return True, "ok"
    except (RedisError, OSError, asyncio.TimeoutError) as exc:
        return False, str(exc)
    finally:
        await client.aclose()


async def check_ai_provider() -> tuple[bool, str]:
    return await ai_review_service.health()


@app.get("/health")
async def health() -> JSONResponse:
    postgres_result, redis_result, ai_result = await asyncio.gather(
        check_postgres(),
        check_redis(),
        check_ai_provider(),
    )
    services = {
        "postgres": {"ok": postgres_result[0], "detail": postgres_result[1]},
        "redis": {"ok": redis_result[0], "detail": redis_result[1]},
        AI_PROVIDER: {"ok": ai_result[0], "detail": ai_result[1]},
    }
    overall_ok = all(service["ok"] for service in services.values())
    payload: dict[str, Any] = {
        "status": "ok" if overall_ok else "degraded",
        "ai_provider": ai_review_service.provider_name,
        "demo_mode": DEMO_MODE,
        "services": services,
    }
    return JSONResponse(status_code=200 if overall_ok else 503, content=payload)


@app.get("/api/auth/status")
async def auth_status() -> dict[str, Any]:
    return {
        "authenticated": False,
        "mode": "demo" if DEMO_MODE else "github_app_oauth",
        "github_app_ready": github_service.oauth_ready,
        "rbac_enabled": True,
        "csrf_protection_enabled": security_config.csrf_protection_enabled,
        "token_rotation_enabled": True,
        "ai_provider": ai_review_service.provider_name,
    }


@app.post("/api/auth/token")
async def issue_token(
    payload: TokenIssueRequest,
    x_bootstrap_token: str | None = Header(default=None),
) -> dict[str, Any]:
    if x_bootstrap_token is None or not secrets.compare_digest(
        x_bootstrap_token, security_config.bootstrap_admin_token
    ):
        audit_logger.security(
            "bootstrap_token_rejected",
            actor=payload.username,
            details={"reason": "invalid bootstrap token"},
        )
        raise HTTPException(status_code=401, detail="Invalid bootstrap token.")

    issued = token_service.issue_token_pair(subject=payload.username, role=payload.role)
    audit_logger.security(
        "token_issued",
        actor=payload.username,
        details={"role": payload.role},
    )
    return issued


@app.post("/api/auth/refresh")
async def refresh_token(payload: TokenRefreshRequest) -> dict[str, Any]:
    issued = token_service.rotate_refresh_token(payload.refresh_token)
    audit_logger.security(
        "refresh_token_rotated",
        actor="refresh-flow",
        details={
            "status": "success",
            "token_fingerprint": sha256(payload.refresh_token.encode("utf-8")).hexdigest()[:16],
        },
    )
    return issued


@app.post("/api/auth/rotate-signing-key")
async def rotate_signing_key(
    context: AuthContext = Depends(require_role("admin")),
) -> dict[str, Any]:
    new_kid = token_service.rotate_signing_key()
    audit_logger.security(
        "jwt_signing_key_rotated",
        actor=context.subject,
        details={"kid": new_kid},
    )
    return {"status": "rotated", "kid": new_kid}


@app.post("/api/oauth/token")
async def store_oauth_token(
    payload: OAuthTokenStoreRequest,
    context: AuthContext = Depends(require_role("operator")),
) -> dict[str, Any]:
    key = oauth_vault_key(payload.provider, payload.owner)
    fingerprint = sha256(payload.access_token.encode("utf-8")).hexdigest()
    vault.set(
        key,
        {
            "provider": payload.provider,
            "owner": payload.owner,
            "access_token": payload.access_token,
            "token_fingerprint": fingerprint,
            "expires_at": payload.expires_at,
            "scopes": payload.scopes,
            "updated_by": context.subject,
        },
    )
    audit_logger.security(
        "oauth_token_stored",
        actor=context.subject,
        details={"provider": payload.provider, "owner": payload.owner},
    )
    return {
        "status": "stored",
        "provider": payload.provider,
        "owner": payload.owner,
        "token_fingerprint": fingerprint[:16],
    }


@app.get("/api/oauth/token/{provider}/{owner}")
async def oauth_token_metadata(
    provider: str,
    owner: str,
    _: AuthContext = Depends(require_role("admin")),
) -> dict[str, Any]:
    key = oauth_vault_key(provider, owner)
    stored = vault.get(key)
    if not isinstance(stored, dict):
        raise HTTPException(status_code=404, detail="OAuth token not found.")
    return {
        "provider": stored.get("provider"),
        "owner": stored.get("owner"),
        "token_fingerprint": str(stored.get("token_fingerprint", ""))[:16],
        "expires_at": stored.get("expires_at"),
        "scopes": stored.get("scopes", []),
    }


@app.get("/api/github/oauth/start")
async def github_oauth_start(
    redirect_uri: str | None = Query(default=None, max_length=500),
    scope: str = Query(default="repo read:org"),
    owner_hint: str | None = Query(default=None, max_length=128),
    context: AuthContext | None = Depends(optional_auth_context),
) -> dict[str, Any]:
    if DEMO_MODE:
        return {"status": "demo", "detail": "GitHub OAuth is not required in demo mode."}
    resolved_owner = resolve_oauth_owner(owner_hint, context)
    payload = github_service.create_oauth_start(
        redirect_uri=redirect_uri,
        scope=scope,
        owner_hint=resolved_owner,
    )
    audit_logger.security(
        "github_oauth_started",
        actor=resolved_owner,
        details={"scope": scope},
    )
    return payload


@app.get("/api/github/oauth/callback")
async def github_oauth_callback(
    code: str = Query(min_length=5),
    state_value: str = Query(alias="state", min_length=8),
    redirect_uri: str | None = Query(default=None, max_length=500),
) -> dict[str, Any]:
    if DEMO_MODE:
        return {"status": "demo", "detail": "Demo mode does not require OAuth callback."}
    return await github_service.complete_oauth_callback(
        code=code,
        state=state_value,
        redirect_uri=redirect_uri,
    )


@app.get("/api/github/oauth/{owner}")
async def github_oauth_owner_status(
    owner: str,
    _: AuthContext = Depends(require_role("viewer")),
) -> dict[str, Any]:
    return github_service.oauth_metadata(owner.lower())


@app.get("/api/repos")
async def list_repositories(
    limit: int = Query(default=50, ge=1, le=100),
    oauth_owner: str | None = Query(default=None, max_length=128),
    context: AuthContext | None = Depends(demo_or_viewer_context),
) -> dict[str, Any]:
    if DEMO_MODE:
        return {"repos": demo_data.list_repositories()[:limit]}
    resolved_oauth_owner = resolve_oauth_owner(oauth_owner, context)
    repos = await github_service.list_repositories(oauth_owner=resolved_oauth_owner, limit=limit)
    return {"owner": resolved_oauth_owner, "repos": repos}


@app.get("/api/repos/{owner}/{repo_name}/pulls")
async def list_pull_requests(
    owner: str,
    repo_name: str,
    limit: int = Query(default=50, ge=1, le=100),
    state_filter: str = Query(default="open", alias="state", pattern="^(open|closed|all)$"),
    oauth_owner: str | None = Query(default=None, max_length=128),
    context: AuthContext | None = Depends(demo_or_viewer_context),
) -> dict[str, Any]:
    if DEMO_MODE:
        pulls = demo_data.list_pull_requests(repo_name)
        return {"owner": owner, "repo": repo_name, "pull_requests": pulls[:limit]}
    resolved_oauth_owner = resolve_oauth_owner(oauth_owner, context)
    pulls = await github_service.list_pull_requests(
        owner=owner,
        repo=repo_name,
        oauth_owner=resolved_oauth_owner,
        limit=limit,
        state_filter=state_filter,
    )
    return {"owner": owner, "repo": repo_name, "pull_requests": pulls}


@app.get("/api/repos/{repo_name}/pulls")
async def list_pull_requests_legacy(
    repo_name: str,
    owner: str | None = Query(default=None, max_length=128),
    limit: int = Query(default=50, ge=1, le=100),
    state_filter: str = Query(default="open", alias="state", pattern="^(open|closed|all)$"),
    oauth_owner: str | None = Query(default=None, max_length=128),
    context: AuthContext | None = Depends(demo_or_viewer_context),
) -> dict[str, Any]:
    if DEMO_MODE:
        pulls = demo_data.list_pull_requests(repo_name)
        return {"repo": repo_name, "pull_requests": pulls[:limit]}
    if not owner:
        raise HTTPException(status_code=400, detail="owner query parameter is required.")
    return await list_pull_requests(
        owner=owner,
        repo_name=repo_name,
        limit=limit,
        state_filter=state_filter,
        oauth_owner=oauth_owner,
        context=context,
    )


@app.get("/api/repos/{owner}/{repo_name}/issues")
async def list_issues(
    owner: str,
    repo_name: str,
    limit: int = Query(default=50, ge=1, le=100),
    state_filter: str = Query(default="open", alias="state", pattern="^(open|closed|all)$"),
    oauth_owner: str | None = Query(default=None, max_length=128),
    context: AuthContext | None = Depends(demo_or_viewer_context),
) -> dict[str, Any]:
    if DEMO_MODE:
        issues = demo_data.list_issues(repo_name)
        return {"owner": owner, "repo": repo_name, "issues": issues[:limit]}
    resolved_oauth_owner = resolve_oauth_owner(oauth_owner, context)
    issues = await github_service.list_issues(
        owner=owner,
        repo=repo_name,
        oauth_owner=resolved_oauth_owner,
        limit=limit,
        state_filter=state_filter,
    )
    return {"owner": owner, "repo": repo_name, "issues": issues}


@app.post("/api/repos/{owner}/{repo_name}/pulls/{pull_number}/merge")
async def merge_pull_request(
    owner: str,
    repo_name: str,
    pull_number: int,
    payload: MergePullRequestRequest,
    oauth_owner: str | None = Query(default=None, max_length=128),
    context: AuthContext | None = Depends(demo_or_viewer_context),
) -> dict[str, Any]:
    if DEMO_MODE:
        actor = context.subject if context is not None else "demo-anonymous"
        merged = demo_data.merge_pull_request(repo_name, pull_number, actor)
        if not merged.get("merged", False):
            raise HTTPException(status_code=404, detail="Demo pull request not found.")
        return merged
    operator_context = ensure_role(context, "operator")
    resolved_oauth_owner = resolve_oauth_owner(oauth_owner, context)
    merged = await github_service.merge_pull_request(
        owner=owner,
        repo=repo_name,
        pull_number=pull_number,
        oauth_owner=resolved_oauth_owner,
        merge_method=payload.merge_method,
        commit_title=payload.commit_title,
    )
    audit_logger.security(
        "pull_request_merge_requested",
        actor=operator_context.subject,
        details={
            "owner": owner,
            "repo": repo_name,
            "pull_number": pull_number,
            "merged": merged.get("merged", False),
        },
    )
    return merged


@app.get("/api/repos/{owner}/{repo_name}/collaborators")
async def list_collaborators(
    owner: str,
    repo_name: str,
    limit: int = Query(default=100, ge=1, le=100),
    oauth_owner: str | None = Query(default=None, max_length=128),
    context: AuthContext | None = Depends(demo_or_viewer_context),
) -> dict[str, Any]:
    if DEMO_MODE:
        collaborators = demo_data.list_collaborators(repo_name)
        return {"owner": owner, "repo": repo_name, "collaborators": collaborators[:limit]}
    resolved_oauth_owner = resolve_oauth_owner(oauth_owner, context)
    collaborators = await github_service.list_collaborators(
        owner=owner,
        repo=repo_name,
        oauth_owner=resolved_oauth_owner,
        limit=limit,
    )
    return {"owner": owner, "repo": repo_name, "collaborators": collaborators}


@app.put("/api/repos/{owner}/{repo_name}/collaborators/{username}")
async def add_or_update_collaborator(
    owner: str,
    repo_name: str,
    username: str,
    payload: CollaboratorUpsertRequest,
    oauth_owner: str | None = Query(default=None, max_length=128),
    context: AuthContext | None = Depends(demo_or_viewer_context),
) -> dict[str, Any]:
    if DEMO_MODE:
        return demo_data.upsert_collaborator(repo_name, username, payload.permission)
    admin_context = ensure_role(context, "admin")
    resolved_oauth_owner = resolve_oauth_owner(oauth_owner, context)
    result = await github_service.add_collaborator(
        owner=owner,
        repo=repo_name,
        username=username,
        oauth_owner=resolved_oauth_owner,
        permission=payload.permission,
    )
    audit_logger.security(
        "collaborator_upserted",
        actor=admin_context.subject,
        details={"owner": owner, "repo": repo_name, "username": username},
    )
    return result


@app.delete("/api/repos/{owner}/{repo_name}/collaborators/{username}")
async def remove_collaborator(
    owner: str,
    repo_name: str,
    username: str,
    oauth_owner: str | None = Query(default=None, max_length=128),
    context: AuthContext | None = Depends(demo_or_viewer_context),
) -> dict[str, Any]:
    if DEMO_MODE:
        result = demo_data.remove_collaborator(repo_name, username)
        if result.get("status") == "not_found":
            raise HTTPException(status_code=404, detail="Collaborator not found in demo data.")
        return result
    admin_context = ensure_role(context, "admin")
    resolved_oauth_owner = resolve_oauth_owner(oauth_owner, context)
    result = await github_service.remove_collaborator(
        owner=owner,
        repo=repo_name,
        username=username,
        oauth_owner=resolved_oauth_owner,
    )
    audit_logger.security(
        "collaborator_removed",
        actor=admin_context.subject,
        details={"owner": owner, "repo": repo_name, "username": username},
    )
    return result


@app.get("/api/ai/status")
async def ai_status(_: AuthContext | None = Depends(demo_or_viewer_context)) -> dict[str, Any]:
    healthy, detail = await ai_review_service.health()
    return {
        "provider": ai_review_service.provider_name,
        "model": ai_review_service.model_name,
        "healthy": healthy,
        "detail": detail,
    }


@app.post("/api/ai/review")
async def review_pull_request_with_ai(
    payload: AIReviewRequest,
    context: AuthContext | None = Depends(demo_or_viewer_context),
) -> dict[str, Any]:
    oauth_owner = ""
    if not DEMO_MODE:
        oauth_owner = resolve_oauth_owner(payload.oauth_owner, context)
    review_context = await build_review_context(
        owner=payload.owner.lower(),
        repo=payload.repo,
        pull_number=payload.pull_number,
        oauth_owner=oauth_owner,
        focus=payload.focus or "",
    )
    try:
        review = await ai_review_service.review_pull_request(review_context)
    except AIProviderError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"AI provider error: {exc}",
        ) from exc
    return {"status": "completed", "review": review}


@app.post("/api/ai/review/jobs")
async def enqueue_ai_review_job(
    payload: AIReviewJobRequest,
    context: AuthContext | None = Depends(demo_or_viewer_context),
) -> dict[str, Any]:
    oauth_owner = ""
    if not DEMO_MODE:
        oauth_owner = resolve_oauth_owner(payload.oauth_owner, context)
    queued_job = await job_queue.enqueue(
        job_type="ai_review",
        payload={
            "owner": payload.owner.lower(),
            "repo": payload.repo,
            "pull_number": payload.pull_number,
            "oauth_owner": oauth_owner,
            "focus": payload.focus or "",
        },
        max_retries=payload.max_retries,
    )
    return {"job": queued_job}


@app.get("/api/jobs/{job_id}")
async def get_job_status(
    job_id: str,
    _: AuthContext | None = Depends(demo_or_viewer_context),
) -> dict[str, Any]:
    job = await job_queue.get_job(job_id)
    if job is None:
        raise HTTPException(status_code=404, detail="Job not found.")
    return {"job": job}


@app.post("/api/plugins/{plugin_name}/run")
async def run_plugin(
    plugin_name: str,
    payload: PluginRunRequest,
    context: AuthContext = Depends(require_role("admin")),
) -> dict[str, Any]:
    try:
        result = plugin_sandbox.execute(plugin_name, payload.args)
    except PluginSandboxError as exc:
        audit_logger.security(
            "plugin_execution_blocked",
            actor=context.subject,
            details={"plugin": plugin_name, "reason": str(exc)},
        )
        raise HTTPException(status_code=403, detail=str(exc)) from exc
    audit_logger.security(
        "plugin_executed",
        actor=context.subject,
        details={"plugin": plugin_name, "status": result["status"]},
    )
    return result
