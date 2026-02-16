from __future__ import annotations

from typing import Any, Protocol


class GitProviderError(RuntimeError):
    def __init__(self, message: str, *, status_code: int = 400) -> None:
        super().__init__(message)
        self.status_code = status_code


class BaseGitProvider(Protocol):
    name: str
    description: str
    supported: bool
    capabilities: set[str]

    async def list_repositories(self, *, oauth_owner: str, limit: int) -> list[dict[str, Any]]:
        raise NotImplementedError

    async def list_pull_requests(
        self,
        *,
        owner: str,
        repo: str,
        oauth_owner: str,
        limit: int,
        state_filter: str,
    ) -> list[dict[str, Any]]:
        raise NotImplementedError

    async def list_issues(
        self,
        *,
        owner: str,
        repo: str,
        oauth_owner: str,
        limit: int,
        state_filter: str,
    ) -> list[dict[str, Any]]:
        raise NotImplementedError

    async def merge_pull_request(
        self,
        *,
        owner: str,
        repo: str,
        pull_number: int,
        oauth_owner: str,
        merge_method: str,
        commit_title: str | None,
        actor: str,
    ) -> dict[str, Any]:
        raise NotImplementedError

    async def list_collaborators(
        self,
        *,
        owner: str,
        repo: str,
        oauth_owner: str,
        limit: int,
    ) -> list[dict[str, Any]]:
        raise NotImplementedError

    async def add_collaborator(
        self,
        *,
        owner: str,
        repo: str,
        username: str,
        oauth_owner: str,
        permission: str,
    ) -> dict[str, Any]:
        raise NotImplementedError

    async def remove_collaborator(
        self,
        *,
        owner: str,
        repo: str,
        username: str,
        oauth_owner: str,
    ) -> dict[str, Any]:
        raise NotImplementedError


class GitHubGitProvider:
    name = "github"
    description = "GitHub REST API provider"
    supported = True
    capabilities = {
        "repos:list",
        "pulls:list",
        "issues:list",
        "pulls:merge",
        "collaborators:list",
        "collaborators:write",
    }

    def __init__(self, github_service: Any) -> None:
        self._github = github_service

    async def list_repositories(self, *, oauth_owner: str, limit: int) -> list[dict[str, Any]]:
        return await self._github.list_repositories(oauth_owner=oauth_owner, limit=limit)

    async def list_pull_requests(
        self,
        *,
        owner: str,
        repo: str,
        oauth_owner: str,
        limit: int,
        state_filter: str,
    ) -> list[dict[str, Any]]:
        return await self._github.list_pull_requests(
            owner=owner,
            repo=repo,
            oauth_owner=oauth_owner,
            limit=limit,
            state_filter=state_filter,
        )

    async def list_issues(
        self,
        *,
        owner: str,
        repo: str,
        oauth_owner: str,
        limit: int,
        state_filter: str,
    ) -> list[dict[str, Any]]:
        return await self._github.list_issues(
            owner=owner,
            repo=repo,
            oauth_owner=oauth_owner,
            limit=limit,
            state_filter=state_filter,
        )

    async def merge_pull_request(
        self,
        *,
        owner: str,
        repo: str,
        pull_number: int,
        oauth_owner: str,
        merge_method: str,
        commit_title: str | None,
        actor: str,
    ) -> dict[str, Any]:
        return await self._github.merge_pull_request(
            owner=owner,
            repo=repo,
            pull_number=pull_number,
            oauth_owner=oauth_owner,
            merge_method=merge_method,
            commit_title=commit_title,
        )

    async def list_collaborators(
        self,
        *,
        owner: str,
        repo: str,
        oauth_owner: str,
        limit: int,
    ) -> list[dict[str, Any]]:
        return await self._github.list_collaborators(
            owner=owner,
            repo=repo,
            oauth_owner=oauth_owner,
            limit=limit,
        )

    async def add_collaborator(
        self,
        *,
        owner: str,
        repo: str,
        username: str,
        oauth_owner: str,
        permission: str,
    ) -> dict[str, Any]:
        return await self._github.add_collaborator(
            owner=owner,
            repo=repo,
            username=username,
            oauth_owner=oauth_owner,
            permission=permission,
        )

    async def remove_collaborator(
        self,
        *,
        owner: str,
        repo: str,
        username: str,
        oauth_owner: str,
    ) -> dict[str, Any]:
        return await self._github.remove_collaborator(
            owner=owner,
            repo=repo,
            username=username,
            oauth_owner=oauth_owner,
        )


class DemoGitProvider:
    name = "demo"
    description = "In-memory demo provider for local workflows"
    supported = True
    capabilities = {
        "repos:list",
        "pulls:list",
        "issues:list",
        "pulls:merge",
        "collaborators:list",
        "collaborators:write",
    }

    def __init__(self, demo_service: Any) -> None:
        self._demo = demo_service

    async def list_repositories(self, *, oauth_owner: str, limit: int) -> list[dict[str, Any]]:
        return self._demo.list_repositories()[:limit]

    async def list_pull_requests(
        self,
        *,
        owner: str,
        repo: str,
        oauth_owner: str,
        limit: int,
        state_filter: str,
    ) -> list[dict[str, Any]]:
        pulls = self._demo.list_pull_requests(repo)
        if state_filter != "all":
            pulls = [item for item in pulls if item.get("status") == state_filter]
        return pulls[:limit]

    async def list_issues(
        self,
        *,
        owner: str,
        repo: str,
        oauth_owner: str,
        limit: int,
        state_filter: str,
    ) -> list[dict[str, Any]]:
        issues = self._demo.list_issues(repo)
        if state_filter != "all":
            issues = [item for item in issues if item.get("status") == state_filter]
        return issues[:limit]

    async def merge_pull_request(
        self,
        *,
        owner: str,
        repo: str,
        pull_number: int,
        oauth_owner: str,
        merge_method: str,
        commit_title: str | None,
        actor: str,
    ) -> dict[str, Any]:
        return self._demo.merge_pull_request(repo, pull_number, actor)

    async def list_collaborators(
        self,
        *,
        owner: str,
        repo: str,
        oauth_owner: str,
        limit: int,
    ) -> list[dict[str, Any]]:
        return self._demo.list_collaborators(repo)[:limit]

    async def add_collaborator(
        self,
        *,
        owner: str,
        repo: str,
        username: str,
        oauth_owner: str,
        permission: str,
    ) -> dict[str, Any]:
        return self._demo.upsert_collaborator(repo, username, permission)

    async def remove_collaborator(
        self,
        *,
        owner: str,
        repo: str,
        username: str,
        oauth_owner: str,
    ) -> dict[str, Any]:
        return self._demo.remove_collaborator(repo, username)


class GitLabGitProvider:
    name = "gitlab"
    description = "Reserved provider boundary for future GitLab integration"
    supported = False
    capabilities: set[str] = set()

    @staticmethod
    def _not_supported() -> None:
        raise GitProviderError(
            "GitLab provider is not implemented yet.",
            status_code=501,
        )

    async def list_repositories(self, *, oauth_owner: str, limit: int) -> list[dict[str, Any]]:
        self._not_supported()

    async def list_pull_requests(
        self,
        *,
        owner: str,
        repo: str,
        oauth_owner: str,
        limit: int,
        state_filter: str,
    ) -> list[dict[str, Any]]:
        self._not_supported()

    async def list_issues(
        self,
        *,
        owner: str,
        repo: str,
        oauth_owner: str,
        limit: int,
        state_filter: str,
    ) -> list[dict[str, Any]]:
        self._not_supported()

    async def merge_pull_request(
        self,
        *,
        owner: str,
        repo: str,
        pull_number: int,
        oauth_owner: str,
        merge_method: str,
        commit_title: str | None,
        actor: str,
    ) -> dict[str, Any]:
        self._not_supported()

    async def list_collaborators(
        self,
        *,
        owner: str,
        repo: str,
        oauth_owner: str,
        limit: int,
    ) -> list[dict[str, Any]]:
        self._not_supported()

    async def add_collaborator(
        self,
        *,
        owner: str,
        repo: str,
        username: str,
        oauth_owner: str,
        permission: str,
    ) -> dict[str, Any]:
        self._not_supported()

    async def remove_collaborator(
        self,
        *,
        owner: str,
        repo: str,
        username: str,
        oauth_owner: str,
    ) -> dict[str, Any]:
        self._not_supported()


class GitProviderRouter:
    def __init__(self) -> None:
        self._providers: dict[str, BaseGitProvider] = {}

    def register(self, provider: BaseGitProvider) -> None:
        self._providers[provider.name] = provider

    def get(self, provider_name: str) -> BaseGitProvider:
        provider = self._providers.get(provider_name)
        if provider is None:
            raise GitProviderError(
                f"Unknown git provider '{provider_name}'.",
                status_code=404,
            )
        return provider

    def list_providers(self) -> list[dict[str, Any]]:
        return [
            {
                "name": provider.name,
                "description": provider.description,
                "supported": provider.supported,
                "capabilities": sorted(provider.capabilities),
            }
            for provider in sorted(self._providers.values(), key=lambda item: item.name)
        ]
