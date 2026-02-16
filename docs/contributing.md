# Contribution Guide

> Documentation version: **v0.2.0**

Thanks for contributing to GitVibeDev.

## 1) Set up local environment

```bash
git clone <your-fork-or-repo-url>
cd GitVibeDev
make up
```

## 2) Create a feature branch

```bash
git checkout -b feat/short-description
```

## 3) Validate before opening PR

Backend syntax check:

```bash
python3 -m compileall backend/app
```

Smoke checks:

```bash
curl -fsS http://localhost:8080/health
curl -fsS http://localhost:8080/api/auth/status
```

## 4) Commit and push

```bash
git add .
git commit -m "feat: add <change>"
git push origin feat/short-description
```

## 5) Pull request expectations

Include in your PR description:

- Problem statement
- What changed
- How you tested it (commands + result)
- Screenshots/GIFs for UI changes
- Any new env vars

## Coding expectations in this repository

- Keep changes modular (`backend/app/*_service.py` pattern)
- Preserve demo mode behavior (`DEMO_MODE=true` path)
- Keep security middleware/auth behavior intact
- Avoid broad exception swallowing
- Prefer small, reviewable PRs

## Documentation updates

If your change affects runtime behavior, also update docs in `/docs`:

- commands
- environment variables
- API contract
- troubleshooting guidance

## Reporting issues

Include:

- exact command executed
- expected vs actual behavior
- relevant logs (`make logs` output excerpt)
- environment details (OS, Docker version)
