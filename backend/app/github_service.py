from __future__ import annotations

import secrets
import time
from dataclasses import dataclass
from typing import Any
from urllib.parse import urlencode

import httpx
from fastapi import HTTPException, status

from .security import AuditLogger
from .vault import LocalVault


@dataclass(frozen=True)
class GitHubConfig:
    client_id: str
    client_secret: str
    app_private_key: str
    oauth_redirect_uri: str
    api_base_url: str = "https://api.github.com"
    oauth_authorize_url: str = "https://github.com/login/oauth/authorize"
    oauth_token_url: str = "https://github.com/login/oauth/access_token"


class GitHubService:
    OAUTH_STATE_PREFIX = "github_oauth_state::"
    OAUTH_STATE_TTL_SECONDS = 600

    def __init__(
        self,
        *,
        config: GitHubConfig,
        vault: LocalVault,
        audit_logger: AuditLogger,
        timeout_seconds: float = 12.0,
    ) -> None:
        self._config = config
        self._vault = vault
        self._audit_logger = audit_logger
        self._timeout_seconds = timeout_seconds

    @property
    def oauth_ready(self) -> bool:
        return bool(self._config.client_id and self._config.client_secret)

    @staticmethod
    def oauth_vault_key(owner: str) -> str:
        return f"oauth::github::{owner.lower()}"

    def _state_vault_key(self, state: str) -> str:
        return f"{self.OAUTH_STATE_PREFIX}{state}"

    def _require_oauth_ready(self) -> None:
        if not self.oauth_ready:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="GitHub OAuth is not configured.",
            )

    @staticmethod
    def _parse_scopes(raw_scopes: str | None) -> list[str]:
        if not raw_scopes:
            return []
        return [scope.strip() for scope in raw_scopes.split(",") if scope.strip()]

    @staticmethod
    def _describe_github_error(response: httpx.Response) -> str:
        try:
            payload = response.json()
        except ValueError:
            payload = {}
        if isinstance(payload, dict):
            message = payload.get("message")
            if isinstance(message, str) and message:
                return message
            error = payload.get("error_description") or payload.get("error")
            if isinstance(error, str) and error:
                return error
        return f"GitHub request failed with status {response.status_code}."

    async def _github_api_request(
        self,
        method: str,
        path: str,
        *,
        oauth_owner: str,
        params: dict[str, Any] | None = None,
        json_body: dict[str, Any] | None = None,
        accept: str = "application/vnd.github+json",
    ) -> httpx.Response:
        access_token = self.get_access_token(oauth_owner)
        headers = {
            "Authorization": f"Bearer {access_token}",
            "Accept": accept,
            "X-GitHub-Api-Version": "2022-11-28",
        }
        async with httpx.AsyncClient(timeout=self._timeout_seconds) as client:
            response = await client.request(
                method=method,
                url=f"{self._config.api_base_url.rstrip('/')}{path}",
                params=params,
                json=json_body,
                headers=headers,
            )
        if response.status_code >= 400:
            detail = self._describe_github_error(response)
            raise HTTPException(
                status_code=response.status_code,
                detail=f"GitHub API error: {detail}",
            )
        return response

    async def _github_api_json(
        self,
        method: str,
        path: str,
        *,
        oauth_owner: str,
        params: dict[str, Any] | None = None,
        json_body: dict[str, Any] | None = None,
    ) -> Any:
        response = await self._github_api_request(
            method,
            path,
            oauth_owner=oauth_owner,
            params=params,
            json_body=json_body,
        )
        try:
            return response.json()
        except ValueError as exc:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="GitHub API returned invalid JSON.",
            ) from exc

    def create_oauth_start(
        self,
        *,
        redirect_uri: str | None,
        scope: str,
        owner_hint: str,
    ) -> dict[str, Any]:
        self._require_oauth_ready()
        resolved_redirect_uri = redirect_uri or self._config.oauth_redirect_uri
        if not resolved_redirect_uri:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="OAuth redirect URI is required.",
            )
        state = secrets.token_urlsafe(24)
        expires_at = int(time.time()) + self.OAUTH_STATE_TTL_SECONDS
        self._vault.set(
            self._state_vault_key(state),
            {
                "expires_at": expires_at,
                "owner_hint": owner_hint.lower(),
                "redirect_uri": resolved_redirect_uri,
            },
        )
        query = urlencode(
            {
                "client_id": self._config.client_id,
                "redirect_uri": resolved_redirect_uri,
                "scope": scope,
                "state": state,
                "allow_signup": "false",
            }
        )
        return {
            "authorize_url": f"{self._config.oauth_authorize_url}?{query}",
            "state": state,
            "expires_at": expires_at,
        }

    def _consume_oauth_state(self, *, state: str, redirect_uri: str | None) -> dict[str, Any]:
        key = self._state_vault_key(state)
        raw = self._vault.get(key)
        self._vault.delete(key)
        if not isinstance(raw, dict):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="OAuth state is missing or invalid.",
            )
        expires_at = int(raw.get("expires_at", 0))
        if expires_at < int(time.time()):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="OAuth state has expired.",
            )
        stored_redirect_uri = str(raw.get("redirect_uri", ""))
        if redirect_uri and stored_redirect_uri and redirect_uri != stored_redirect_uri:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="OAuth redirect URI mismatch.",
            )
        return raw

    async def _exchange_oauth_code(
        self, *, code: str, redirect_uri: str | None
    ) -> dict[str, Any]:
        payload: dict[str, Any] = {
            "client_id": self._config.client_id,
            "client_secret": self._config.client_secret,
            "code": code,
        }
        if redirect_uri:
            payload["redirect_uri"] = redirect_uri
        async with httpx.AsyncClient(timeout=self._timeout_seconds) as client:
            response = await client.post(
                self._config.oauth_token_url,
                data=payload,
                headers={"Accept": "application/json"},
            )
        if response.status_code >= 400:
            detail = self._describe_github_error(response)
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"GitHub OAuth exchange failed: {detail}",
            )
        try:
            token_payload = response.json()
        except ValueError as exc:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="GitHub OAuth response was not valid JSON.",
            ) from exc
        if not isinstance(token_payload, dict):
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="GitHub OAuth response format is invalid.",
            )
        access_token = token_payload.get("access_token")
        if not isinstance(access_token, str) or not access_token:
            detail = token_payload.get("error_description") or token_payload.get("error")
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"GitHub OAuth did not return an access token: {detail}",
            )
        return token_payload

    async def _fetch_user(self, *, access_token: str) -> dict[str, Any]:
        headers = {
            "Authorization": f"Bearer {access_token}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
        }
        async with httpx.AsyncClient(timeout=self._timeout_seconds) as client:
            response = await client.get(
                f"{self._config.api_base_url.rstrip('/')}/user",
                headers=headers,
            )
        if response.status_code >= 400:
            detail = self._describe_github_error(response)
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"Failed to fetch GitHub user profile: {detail}",
            )
        payload = response.json()
        if not isinstance(payload, dict) or not isinstance(payload.get("login"), str):
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="GitHub user response is invalid.",
            )
        return payload

    def _store_token(
        self,
        *,
        owner: str,
        access_token: str,
        scopes: list[str],
        token_type: str,
    ) -> None:
        self._vault.set(
            self.oauth_vault_key(owner),
            {
                "provider": "github",
                "owner": owner,
                "access_token": access_token,
                "scopes": scopes,
                "token_type": token_type,
                "updated_at": int(time.time()),
            },
        )

    async def complete_oauth_callback(
        self, *, code: str, state: str, redirect_uri: str | None
    ) -> dict[str, Any]:
        self._require_oauth_ready()
        state_payload = self._consume_oauth_state(state=state, redirect_uri=redirect_uri)
        resolved_redirect_uri = redirect_uri or str(state_payload.get("redirect_uri", ""))
        token_payload = await self._exchange_oauth_code(
            code=code,
            redirect_uri=resolved_redirect_uri or None,
        )
        access_token = str(token_payload["access_token"])
        user_payload = await self._fetch_user(access_token=access_token)
        owner = str(user_payload["login"]).lower()
        scopes = self._parse_scopes(token_payload.get("scope"))
        token_type = str(token_payload.get("token_type", "bearer"))
        self._store_token(
            owner=owner,
            access_token=access_token,
            scopes=scopes,
            token_type=token_type,
        )
        self._audit_logger.security(
            "github_oauth_completed",
            actor=owner,
            details={"scopes": scopes, "owner_hint": state_payload.get("owner_hint")},
        )
        return {
            "status": "connected",
            "owner": owner,
            "scopes": scopes,
            "token_type": token_type,
        }

    def get_access_token(self, oauth_owner: str) -> str:
        raw = self._vault.get(self.oauth_vault_key(oauth_owner))
        if not isinstance(raw, dict):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="GitHub OAuth token not found for owner.",
            )
        access_token = raw.get("access_token")
        if not isinstance(access_token, str) or not access_token:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Stored GitHub OAuth token is invalid.",
            )
        return access_token

    def oauth_metadata(self, oauth_owner: str) -> dict[str, Any]:
        raw = self._vault.get(self.oauth_vault_key(oauth_owner))
        if not isinstance(raw, dict):
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="GitHub OAuth token not found for owner.",
            )
        return {
            "provider": raw.get("provider", "github"),
            "owner": raw.get("owner", oauth_owner.lower()),
            "scopes": raw.get("scopes", []),
            "token_type": raw.get("token_type", "bearer"),
            "updated_at": raw.get("updated_at"),
        }

    async def list_repositories(self, *, oauth_owner: str, limit: int) -> list[dict[str, Any]]:
        payload = await self._github_api_json(
            "GET",
            "/user/repos",
            oauth_owner=oauth_owner,
            params={"per_page": limit, "sort": "updated", "direction": "desc"},
        )
        if not isinstance(payload, list):
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Unexpected repository payload from GitHub.",
            )
        repos: list[dict[str, Any]] = []
        for item in payload:
            if not isinstance(item, dict):
                continue
            owner_payload = item.get("owner")
            repos.append(
                {
                    "id": item.get("id"),
                    "name": item.get("name"),
                    "full_name": item.get("full_name"),
                    "owner": owner_payload.get("login") if isinstance(owner_payload, dict) else "",
                    "private": bool(item.get("private", False)),
                    "default_branch": item.get("default_branch"),
                    "open_issues": item.get("open_issues_count", 0),
                }
            )
        return repos

    async def list_pull_requests(
        self,
        *,
        owner: str,
        repo: str,
        oauth_owner: str,
        limit: int,
        state_filter: str,
    ) -> list[dict[str, Any]]:
        payload = await self._github_api_json(
            "GET",
            f"/repos/{owner}/{repo}/pulls",
            oauth_owner=oauth_owner,
            params={"state": state_filter, "per_page": limit},
        )
        if not isinstance(payload, list):
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Unexpected pull request payload from GitHub.",
            )
        pulls: list[dict[str, Any]] = []
        for item in payload:
            if not isinstance(item, dict):
                continue
            user_payload = item.get("user")
            pulls.append(
                {
                    "number": item.get("number"),
                    "title": item.get("title"),
                    "status": item.get("state"),
                    "author": user_payload.get("login") if isinstance(user_payload, dict) else "",
                    "html_url": item.get("html_url"),
                    "mergeable_state": item.get("mergeable_state"),
                }
            )
        return pulls

    async def list_issues(
        self,
        *,
        owner: str,
        repo: str,
        oauth_owner: str,
        limit: int,
        state_filter: str,
    ) -> list[dict[str, Any]]:
        payload = await self._github_api_json(
            "GET",
            f"/repos/{owner}/{repo}/issues",
            oauth_owner=oauth_owner,
            params={"state": state_filter, "per_page": limit},
        )
        if not isinstance(payload, list):
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Unexpected issue payload from GitHub.",
            )
        issues: list[dict[str, Any]] = []
        for item in payload:
            if not isinstance(item, dict) or "pull_request" in item:
                continue
            user_payload = item.get("user")
            issues.append(
                {
                    "number": item.get("number"),
                    "title": item.get("title"),
                    "status": item.get("state"),
                    "author": user_payload.get("login") if isinstance(user_payload, dict) else "",
                    "labels": [
                        label.get("name")
                        for label in item.get("labels", [])
                        if isinstance(label, dict) and isinstance(label.get("name"), str)
                    ],
                    "html_url": item.get("html_url"),
                }
            )
        return issues

    async def merge_pull_request(
        self,
        *,
        owner: str,
        repo: str,
        pull_number: int,
        oauth_owner: str,
        merge_method: str,
        commit_title: str | None,
    ) -> dict[str, Any]:
        payload = await self._github_api_json(
            "PUT",
            f"/repos/{owner}/{repo}/pulls/{pull_number}/merge",
            oauth_owner=oauth_owner,
            json_body={
                "merge_method": merge_method,
                "commit_title": commit_title,
            },
        )
        if not isinstance(payload, dict):
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Unexpected merge payload from GitHub.",
            )
        return {
            "merged": bool(payload.get("merged")),
            "message": payload.get("message"),
            "sha": payload.get("sha"),
        }

    async def list_collaborators(
        self,
        *,
        owner: str,
        repo: str,
        oauth_owner: str,
        limit: int,
    ) -> list[dict[str, Any]]:
        payload = await self._github_api_json(
            "GET",
            f"/repos/{owner}/{repo}/collaborators",
            oauth_owner=oauth_owner,
            params={"per_page": limit},
        )
        if not isinstance(payload, list):
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Unexpected collaborators payload from GitHub.",
            )
        collaborators: list[dict[str, Any]] = []
        for item in payload:
            if not isinstance(item, dict):
                continue
            collaborators.append(
                {
                    "login": item.get("login"),
                    "id": item.get("id"),
                    "type": item.get("type"),
                    "permissions": item.get("permissions", {}),
                }
            )
        return collaborators

    async def add_collaborator(
        self,
        *,
        owner: str,
        repo: str,
        username: str,
        oauth_owner: str,
        permission: str,
    ) -> dict[str, Any]:
        response = await self._github_api_request(
            "PUT",
            f"/repos/{owner}/{repo}/collaborators/{username}",
            oauth_owner=oauth_owner,
            json_body={"permission": permission},
        )
        status_name = "invited" if response.status_code == 201 else "updated"
        return {"status": status_name, "username": username, "permission": permission}

    async def remove_collaborator(
        self,
        *,
        owner: str,
        repo: str,
        username: str,
        oauth_owner: str,
    ) -> dict[str, Any]:
        await self._github_api_request(
            "DELETE",
            f"/repos/{owner}/{repo}/collaborators/{username}",
            oauth_owner=oauth_owner,
        )
        return {"status": "removed", "username": username}

    async def get_pull_review_context(
        self,
        *,
        owner: str,
        repo: str,
        pull_number: int,
        oauth_owner: str,
    ) -> dict[str, Any]:
        pull_payload = await self._github_api_json(
            "GET",
            f"/repos/{owner}/{repo}/pulls/{pull_number}",
            oauth_owner=oauth_owner,
        )
        if not isinstance(pull_payload, dict):
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Unexpected pull request payload from GitHub.",
            )
        diff_response = await self._github_api_request(
            "GET",
            f"/repos/{owner}/{repo}/pulls/{pull_number}",
            oauth_owner=oauth_owner,
            accept="application/vnd.github.v3.diff",
        )
        return {
            "owner": owner,
            "repo": repo,
            "pull_number": pull_number,
            "title": pull_payload.get("title", ""),
            "body": pull_payload.get("body", ""),
            "html_url": pull_payload.get("html_url", ""),
            "diff": diff_response.text,
        }
