# Governance Model

> Governance spec version: **v1.0.0**

## Project mission

GitVibeDev is an open-source, self-hostable developer platform focused on secure Git workflows and AI-assisted collaboration.

## Governance goals

- Keep decision-making transparent and documented.
- Maintain predictable release quality.
- Empower contributors to become maintainers through clear expectations.

## Roles

### Contributors

- Submit issues, RFCs, pull requests, docs, and reviews.
- Sign CLA before code contributions are merged.

### Maintainers

- Review and merge pull requests.
- Triage issues and moderate release cadence.
- Uphold security and disclosure policy.

### Core maintainers

- Final decision authority for roadmap direction.
- Approve breaking changes and governance updates.
- Steward release tags and branch protections.

## Decision process

1. Minor changes: maintainer consensus in PR discussion.
2. Significant changes: RFC required under `docs/rfcs/`.
3. Breaking API or architecture changes: approval from at least one core maintainer.

## Release ownership

- Releases follow Semantic Versioning (`MAJOR.MINOR.PATCH`).
- `VERSION` file is the source of truth.
- `CHANGELOG.md` must include release notes before tag cut.

## Maintainer onboarding and offboarding

- New maintainers are nominated in discussion and approved by two existing maintainers (including one core maintainer).
- Inactive maintainers can be moved to emeritus status after public notice and no response window.

## Governance updates

Governance updates require an RFC and core maintainer approval.
