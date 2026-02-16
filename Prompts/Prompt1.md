You are a senior DevOps architect and open-source platform engineer.

I am building an open-source, AI-native GitHub frontend platform.

Your task is to generate a production-grade setup system that makes installation trivial.

GOAL:
From zero to running app in under 5 minutes using:

    curl -fsSL https://example.com/install.sh | bash

The project must be:

- Fully open source
- Docker-first
- Self-hostable
- AI-native
- Local LLM compatible (Ollama by default)
- PostgreSQL
- Redis for background jobs
- FastAPI backend
- Web frontend (placeholder is fine)
- GitHub App OAuth ready
- Demo mode supported

-------------------------------------------------------
PHASE 1: OUTPUT REQUIREMENTS
-------------------------------------------------------

Generate:

1. docker-compose.yml
   - backend
   - frontend
   - postgres
   - redis
   - ollama
   - persistent volumes
   - health checks

2. .env.example
   - sensible defaults
   - AI_PROVIDER=ollama
   - demo mode option
   - secure secret placeholders

3. installer/install.sh
   - Detect OS (Linux/macOS)
   - Install Docker if missing
   - Clone repo
   - Generate .env if missing
   - Generate secure secrets automatically
   - Run docker compose up -d
   - Print URL
   - Fail gracefully with helpful messages

4. Makefile with:
   - make up
   - make down
   - make logs
   - make reset
   - make update

5. Backend health endpoint:
   - /health
   - Checks DB
   - Checks Redis
   - Checks Ollama
   - Returns JSON status

6. Demo Mode:
   - If DEMO_MODE=true
   - Skip GitHub auth
   - Seed fake repos
   - Return fake PR data

-------------------------------------------------------
ARCHITECTURE RULES
-------------------------------------------------------

- Everything must run with only:
      docker compose up

- No manual database setup
- No manual AI install
- No external dependencies required beyond Docker
- Secrets auto-generated
- Clear comments in all files
- Production-safe defaults

-------------------------------------------------------
QUALITY STANDARDS
-------------------------------------------------------

- Clean structure
- No hardcoded localhost where inappropriate
- Use environment variables everywhere
- Add comments explaining decisions
- Follow modern Docker best practices
- Include healthcheck definitions in docker-compose
- Include restart policies
- Use named volumes

-------------------------------------------------------
SECURITY REQUIREMENTS
-------------------------------------------------------

- Generate SECRET_KEY automatically
- Never hardcode credentials
- Encrypt sensitive values (placeholder ok)
- Do not expose internal ports unnecessarily

-------------------------------------------------------
OUTPUT FORMAT
-------------------------------------------------------

Output in this order:

1. Project directory structure
2. docker-compose.yml
3. .env.example
4. installer/install.sh
5. Makefile
6. FastAPI minimal backend with /health endpoint
7. Demo mode mock service example

All code must be complete and runnable.

Do not explain. Just generate production-ready files.

