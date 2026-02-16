from __future__ import annotations

from dataclasses import dataclass
from typing import Any


@dataclass
class MockTextResponse:
    text: str


class MockGitHubAPI:
    def __init__(self) -> None:
        self.repos = [
            {
                "id": 1,
                "name": "alpha",
                "full_name": "demo/alpha",
                "owner": {"login": "demo"},
                "private": False,
                "default_branch": "main",
                "open_issues_count": 3,
            }
        ]
        self.pulls = [
            {
                "number": 7,
                "title": "fix: sample",
                "state": "open",
                "user": {"login": "alice"},
                "html_url": "https://example/pull/7",
                "mergeable_state": "clean",
            }
        ]
        self.issues = [
            {
                "number": 12,
                "title": "Issue sample",
                "state": "open",
                "user": {"login": "bob"},
                "labels": [{"name": "bug"}],
                "html_url": "https://example/issue/12",
            },
            {
                "number": 13,
                "title": "PR pseudo issue",
                "state": "open",
                "user": {"login": "alice"},
                "labels": [],
                "pull_request": {},
            },
        ]
        self.collaborators = [
            {"login": "alice", "id": 10, "type": "User", "permissions": {"push": True}}
        ]

    def json_response(
        self,
        method: str,
        path: str,
        *,
        params: dict[str, Any] | None = None,
        json_body: dict[str, Any] | None = None,
    ) -> Any:
        if method == "GET" and path == "/user/repos":
            return self.repos
        if method == "GET" and path.endswith("/pulls"):
            state = (params or {}).get("state", "open")
            if state == "all":
                return self.pulls
            return [item for item in self.pulls if item.get("state") == state]
        if method == "GET" and path.endswith("/issues"):
            return self.issues
        if method == "PUT" and path.endswith("/merge"):
            return {"merged": True, "message": "merged", "sha": "abc123"}
        if method == "GET" and path.endswith("/collaborators"):
            return self.collaborators
        if method == "GET" and "/pulls/" in path:
            return {
                "title": "Mock PR",
                "body": "Mock body",
                "html_url": "https://example/pr",
            }
        raise AssertionError(f"Unhandled mock route: {method} {path}")

    def request_response(self, method: str, path: str) -> MockTextResponse:
        if method == "GET" and "/pulls/" in path:
            return MockTextResponse(text="diff --git a/a.py b/a.py\n+print('hi')\n")
        raise AssertionError(f"Unhandled text route: {method} {path}")
