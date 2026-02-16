You are a senior full-stack architect and open-source maintainer.

You are fixing and completing an AI-native platform called “GitVibe”
for a competitive technical evaluation.

An independent audit reported:

STRENGTHS:
- Production-grade backend (OAuth, GitHub APIs, async AI review)
- Strong security middleware (JWT rotation, CSRF, RBAC, rate limiting)
- Well-designed plugin/agent/workflow framework
- Robust installer and hardened Docker setup
- Accurate technical documentation

FAILURES:
- No functional UI (only static mockup)
- Overengineered infrastructure (unused Postgres/Redis)
- Missing README, LICENSE, .gitignore
- Test infrastructure exists but is unverified

Your task is to FIX ALL FAILURES without breaking existing strengths.

--------------------------------------------------
PRIMARY OBJECTIVE
--------------------------------------------------

Transform GitVibe into a complete, usable, judge-ready product.

Focus on functionality over perfection.

--------------------------------------------------
TASK 1 — BUILD A REAL UI (CRITICAL)
--------------------------------------------------

Implement a functional frontend that connects to the backend.

Requirements:

- Modern framework (Next.js or React preferred)
- Authentication flow
- Repo listing page
- PR listing/view page
- AI review trigger
- Merge button
- Settings page
- Error handling
- Loading states

Constraints:

- No placeholder mockups
- Must call real backend APIs
- Must work out-of-the-box via Docker

--------------------------------------------------
TASK 2 — SIMPLIFY DEFAULT INFRASTRUCTURE
--------------------------------------------------

Reduce unnecessary complexity.

Implement:

Option A (Preferred):
- SQLite as default DB
- Postgres/Redis in "full" profile

OR

Option B:
- Minimal compose profile without Postgres/Redis

Add:

- FAST_BOOT=true mode
- Clear documentation

--------------------------------------------------
TASK 3 — ADD REPO HYGIENE FILES
--------------------------------------------------

Create and populate:

- README.md (Quick Start, Features, Demo, Architecture)
- LICENSE (Open-source approved)
- .gitignore (Backend, Frontend, Docker, IDE)

README must be contest-quality.

--------------------------------------------------
TASK 4 — ACTIVATE AND VERIFY TESTING
--------------------------------------------------

Ensure tests actually run.

Implement:

- Working test commands
- GitHub Actions CI
- Docker-based integration tests
- Mock GitHub API
- Mock AI providers

All tests must pass.

--------------------------------------------------
TASK 5 — POLISH INSTALLATION EXPERIENCE
--------------------------------------------------

Improve installer if needed:

- Faster startup
- Better error messages
- Dependency checks
- Health verification

Ensure:

curl | bash → working UI + backend

--------------------------------------------------
TASK 6 — DOCUMENT FIXES
--------------------------------------------------

Update docs to reflect:

- UI usage
- Minimal vs full mode
- Testing
- Troubleshooting

--------------------------------------------------
QUALITY STANDARDS
--------------------------------------------------

- Do not break security model
- Do not weaken permissions
- Preserve plugin/agent framework
- Maintain modular design
- Keep setup trivial
- Prefer clarity over complexity
- Add comments where non-obvious

--------------------------------------------------
DELIVERABLE
--------------------------------------------------

Provide:

1. Updated directory structure
2. Complete frontend implementation
3. Revised docker-compose profiles
4. New README, LICENSE, .gitignore
5. CI configuration
6. Test verification output
7. Setup verification steps

All output must be production-ready.

No explanations.
No placeholders.
No TODOs.
Fix everything properly.

