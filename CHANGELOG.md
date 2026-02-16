# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Platform scalability framework modules (plugin/agent/workflow/event bus boundaries).
- Community operations foundation: release workflows, CLA, governance, RFC process.

### Changed
- Introduced the new **GitVibe Aurora** frontend theme in `frontend/styles.css` with dark-first glassmorphism panels, aurora accents, refined spacing, and improved visual hierarchy.
- Updated frontend presentation markup in `frontend/app.js` and metadata in `frontend/index.html` to support the Aurora visual system without changing API, auth, routing, or demo-mode behavior.

### Notes
- **Why:** Refresh the UI into a developer-focused console aesthetic while preserving all existing product logic and backend contracts.
- **How to revert:** `git checkout -- frontend/styles.css frontend/app.js frontend/index.html CHANGELOG.md && rm -f SUMMARY.md`

## [0.2.0] - 2026-02-16

### Added
- GitHub OAuth, repository/PR/issue/collaborator APIs, and merge actions.
- AI provider abstraction with Ollama and OpenAI-compatible support.
- Persistent background job queue with retry.
- Keyboard-first frontend workflow shell and complete docs set under `/docs`.

[Unreleased]: https://github.com/mesubbu/gitvibeDev/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/mesubbu/gitvibeDev/releases/tag/v0.2.0
