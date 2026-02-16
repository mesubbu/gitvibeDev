<div align="center">

# 🎸 GitVibe

**AI-Native GitHub Frontend for Vibe Coders**

[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-0.2.0-green.svg)](VERSION)
[![CI](https://img.shields.io/badge/CI-passing-brightgreen.svg)](.github/workflows/ci.yml)

*Review PRs with AI. Merge with confidence. Ship faster.*

</div>

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| 🤖 **AI Code Review** | One-click AI-powered PR review via Ollama or OpenAI-compatible APIs |
| 🔐 **GitHub OAuth** | Secure OAuth flow with encrypted token vault |
| 📋 **PR & Issue Management** | List, view, and merge pull requests; browse issues |
| 👥 **Collaborator Management** | Add, update, and remove repo collaborators |
| 🎮 **Demo Mode** | Try everything without GitHub credentials |
| 🔌 **Plugin System** | Extend with custom plugins, agents, and workflows |
| 🛡️ **Security First** | JWT + CSRF + RBAC + rate limiting + audit logging |
| 🐳 **Docker Ready** | One-command deployment with Docker Compose |

---

## 🚀 Quick Start

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) and Docker Compose
- (Optional) A [GitHub OAuth App](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/creating-an-oauth-app) for live GitHub access

### 1. Clone & Start

```bash
git clone https://github.com/mesubbu/gitvibeDev.git
cd gitvibeDev
```

**Option A — Local (no Docker):**

```bash
make local
```

This creates a Python venv, installs dependencies, and starts the backend + frontend dev server. Visit **http://localhost:3000**.

**Option B — Docker:**

```bash
make up
```

This starts the backend, frontend, and Ollama in Docker. Visit **http://localhost:3000**.

**Option C — Frontend-only secure demo (no backend):**

```bash
cp .env.example .env
APP_MODE=demo docker compose --env-file .env up -d frontend
```

This starts only Nginx + frontend with local mock API/auth/storage.

### 2. Demo Mode

Set `APP_MODE=demo` to run the secure offline demo — no GitHub credentials needed.  
You get seeded repos, PRs, issues, and AI review responses stored locally in the browser.

### Runtime Modes

Set one variable to switch behavior:

```bash
APP_MODE=demo|development|production
```

| APP_MODE | Behavior |
|----------|----------|
| `demo` | Frontend-only local mocks (no backend/DB/Redis/auth services) |
| `development` | Frontend + real backend APIs |
| `production` | Real backend APIs with production deployment controls |

### 3. Live GitHub Mode

Create a `.env` file (or edit the auto-generated one):

```bash
DEMO_MODE=false
GITHUB_CLIENT_ID=your_oauth_client_id
GITHUB_CLIENT_SECRET=your_oauth_client_secret
```

Then restart:

```bash
make down && make up
```

---

## 🏗️ Architecture

```
┌─────────────┐     ┌─────────────────┐     ┌──────────┐
│   Browser    │────▶│  Nginx (:3000)  │────▶│  Backend  │
│   (SPA)      │     │  Static + Proxy │     │  FastAPI  │
└─────────────┘     └─────────────────┘     │  (:8000)  │
                                             └─────┬─────┘
                                                   │
                                    ┌──────────────┼──────────────┐
                                    │              │              │
                              ┌─────▼─────┐ ┌─────▼─────┐ ┌─────▼─────┐
                              │  GitHub   │ │  Ollama   │ │   Vault   │
                              │  REST API │ │  (AI)     │ │  (Secrets)│
                              └───────────┘ └───────────┘ └───────────┘
```

**Backend**: Python FastAPI with JWT auth, RBAC, CSRF protection, rate limiting, audit logging.  
**Frontend**: Lightweight SPA served by Nginx, calling real backend APIs.  
**AI**: Pluggable providers — Ollama (local) or any OpenAI-compatible API.  
**Storage**: Encrypted file vault for tokens and secrets. No database required by default.

---

## 📦 Docker Compose Profiles

| Profile | Services | Use Case |
|---------|----------|----------|
| `make local` | Backend + Frontend (Python only) | Quick local dev, no Docker |
| `make up` (default) | Backend + Frontend + Ollama | Demo & Docker-based dev |
| `make up-full` | + PostgreSQL + Redis | Production with persistence |

Stop local services with `make local-stop`.

---

## 🔧 Configuration

All configuration via environment variables (`.env` file):

| Variable | Default | Description |
|----------|---------|-------------|
| `DEMO_MODE` | `true` | Enable demo mode with sample data |
| `GITHUB_CLIENT_ID` | — | GitHub OAuth App client ID |
| `GITHUB_CLIENT_SECRET` | — | GitHub OAuth App client secret |
| `AI_PROVIDER` | `ollama` | AI provider: `ollama` or `openai` |
| `OLLAMA_BASE_URL` | `http://ollama:11434` | Ollama API endpoint |
| `OPENAI_API_KEY` | — | OpenAI API key (if using OpenAI) |
| `AI_MODEL` | `codellama` | AI model name |
| `SECRET_KEY` | *auto-generated* | JWT signing key |
| `FAST_BOOT` | `false` | Skip optional service health checks |

See [`.env.example`](.env.example) for the full list.

---

## 🧪 Testing

```bash
# Install dev dependencies
make dev-deps

# Fast unit tests
make test-fast

# Full test suite
make test

# With coverage report
make coverage
```

---

## 📖 Documentation

| Document | Description |
|----------|-------------|
| [Installation Guide](docs/installation.md) | Detailed setup instructions |
| [Architecture](docs/architecture.md) | System design and components |
| [API Reference](docs/api.md) | Complete REST API documentation |
| [AI Configuration](docs/ai-configuration.md) | Configure AI providers |
| [Plugin Development](docs/plugin-development.md) | Build custom plugins |
| [Contributing](docs/contributing.md) | Contribution guidelines |
| [Troubleshooting](docs/troubleshooting.md) | Common issues and fixes |

---

## 🤝 Contributing

We welcome contributions! See [CONTRIBUTING](docs/contributing.md) for guidelines.

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing`)
3. Make your changes
4. Run tests (`make test`)
5. Submit a pull request

---

## 📄 License

Licensed under the [Apache License 2.0](LICENSE).

---

<div align="center">

**Built for vibe coders** 🎸

</div>
