from __future__ import annotations

import time
from typing import Any


class DemoDataService:
    """In-memory demo data provider used when DEMO_MODE=true."""

    def __init__(self) -> None:
        self._repos: list[dict[str, Any]] = []
        self._pulls_by_repo: dict[str, list[dict[str, Any]]] = {}
        self._issues_by_repo: dict[str, list[dict[str, Any]]] = {}
        self._collaborators_by_repo: dict[str, list[dict[str, Any]]] = {}
        self._pull_diffs_by_repo: dict[str, dict[int, str]] = {}

    def seed(self) -> None:
        self._repos = [
            {
                "id": 101,
                "name": "platform-api",
                "owner": "demo-org",
                "default_branch": "main",
                "open_prs": 2,
            },
            {
                "id": 102,
                "name": "platform-web",
                "owner": "demo-org",
                "default_branch": "main",
                "open_prs": 1,
            },
        ]
        self._pulls_by_repo = {
            "platform-api": [
                {
                    "number": 42,
                    "title": "feat: add AI repo insights endpoint",
                    "author": "copilot-bot",
                    "status": "open",
                    "checks": "passing",
                },
                {
                    "number": 44,
                    "title": "fix: tighten webhook signature validation",
                    "author": "security-maintainer",
                    "status": "open",
                    "checks": "pending",
                },
            ],
            "platform-web": [
                {
                    "number": 13,
                    "title": "chore: improve dashboard loading states",
                    "author": "frontend-dev",
                    "status": "open",
                    "checks": "passing",
                }
            ],
        }
        self._issues_by_repo = {
            "platform-api": [
                {
                    "number": 8,
                    "title": "api: harden OAuth callback validation",
                    "author": "security-maintainer",
                    "status": "open",
                    "labels": ["security"],
                },
                {
                    "number": 9,
                    "title": "api: add queue retries for review jobs",
                    "author": "backend-dev",
                    "status": "open",
                    "labels": ["backend"],
                },
            ],
            "platform-web": [
                {
                    "number": 3,
                    "title": "web: improve merge action feedback",
                    "author": "frontend-dev",
                    "status": "open",
                    "labels": ["ux"],
                }
            ],
        }
        self._collaborators_by_repo = {
            "platform-api": [
                {"login": "maintainer", "permission": "admin"},
                {"login": "backend-dev", "permission": "push"},
            ],
            "platform-web": [
                {"login": "maintainer", "permission": "admin"},
                {"login": "frontend-dev", "permission": "push"},
            ],
        }
        self._pull_diffs_by_repo = {
            "platform-api": {
                42: (
                    "diff --git a/app/main.py b/app/main.py\n"
                    "@@ -12,6 +12,9 @@\n"
                    "+from .ai import RepoInsights\n"
                    "+\n"
                    "+@app.get('/api/repos/{repo}/insights')\n"
                    "+async def repo_insights(repo: str): ...\n"
                ),
                44: (
                    "diff --git a/app/auth.py b/app/auth.py\n"
                    "@@ -20,7 +20,8 @@\n"
                    "-if not signature:\n"
                    "+if not signature or not timestamp:\n"
                    "     raise HTTPException(status_code=401)\n"
                ),
            },
            "platform-web": {
                13: (
                    "diff --git a/src/components/dashboard.tsx b/src/components/dashboard.tsx\n"
                    "@@ -1,4 +1,6 @@\n"
                    "+const LoadingState = () => <Spinner />\n"
                    " export default function Dashboard() { ... }\n"
                )
            },
        }

    def list_repositories(self) -> list[dict[str, Any]]:
        return self._repos

    def list_pull_requests(self, repo_name: str) -> list[dict[str, Any]]:
        return self._pulls_by_repo.get(repo_name, [])

    def list_issues(self, repo_name: str) -> list[dict[str, Any]]:
        return self._issues_by_repo.get(repo_name, [])

    def merge_pull_request(self, repo_name: str, pull_number: int, merged_by: str) -> dict[str, Any]:
        pulls = self._pulls_by_repo.get(repo_name, [])
        for pull in pulls:
            if int(pull.get("number", -1)) != pull_number:
                continue
            if pull.get("status") == "merged":
                return {"merged": True, "message": "Pull request already merged."}
            pull["status"] = "merged"
            pull["merged_by"] = merged_by
            pull["merged_at"] = int(time.time())
            return {"merged": True, "message": "Pull request merged in demo mode."}
        return {"merged": False, "message": "Pull request not found."}

    def list_collaborators(self, repo_name: str) -> list[dict[str, Any]]:
        return self._collaborators_by_repo.get(repo_name, [])

    def upsert_collaborator(
        self, repo_name: str, username: str, permission: str
    ) -> dict[str, Any]:
        collaborators = self._collaborators_by_repo.setdefault(repo_name, [])
        for collaborator in collaborators:
            if collaborator.get("login") == username:
                collaborator["permission"] = permission
                return {"status": "updated", "username": username, "permission": permission}
        collaborators.append({"login": username, "permission": permission})
        return {"status": "invited", "username": username, "permission": permission}

    def remove_collaborator(self, repo_name: str, username: str) -> dict[str, Any]:
        collaborators = self._collaborators_by_repo.setdefault(repo_name, [])
        original_len = len(collaborators)
        collaborators[:] = [item for item in collaborators if item.get("login") != username]
        if len(collaborators) == original_len:
            return {"status": "not_found", "username": username}
        return {"status": "removed", "username": username}

    def pull_review_context(self, repo_name: str, pull_number: int) -> dict[str, Any]:
        pulls = self._pulls_by_repo.get(repo_name, [])
        selected_pull = next(
            (pull for pull in pulls if int(pull.get("number", -1)) == pull_number),
            None,
        )
        if not isinstance(selected_pull, dict):
            return {}
        diff = self._pull_diffs_by_repo.get(repo_name, {}).get(pull_number, "")
        return {
            "owner": selected_pull.get("owner", "demo-org"),
            "repo": repo_name,
            "pull_number": pull_number,
            "title": selected_pull.get("title", ""),
            "body": "Demo pull request generated by DemoDataService.",
            "html_url": f"https://example.local/{repo_name}/pull/{pull_number}",
            "diff": diff,
        }
