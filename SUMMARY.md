# GitVibe Aurora — Frontend Summary

## 1) Component map

### Runtime + boot flow
- `frontend/index.html`
  - Loads `styles.css`, `/runtime-config.js`, `runtime/runtime.js`, then `app.js`.
  - Hosts root containers: `#app` and `#toast-container`.
- `frontend/runtime/runtime.js`
  - Builds runtime adapters from `APP_MODE`.
  - `demo` mode: `MockApiClient` + `MockAuthProvider` + persisted demo state.
  - `development/production`: `HttpApiClient` for backend APIs.
- `frontend/app.js`
  - `bootstrap()` initializes runtime, fetches health/auth/repos, and renders the SPA.

### UI render tree (single-page app)
- `render()`
  - `renderHeader()`
  - `renderModeBanner()` (demo-only)
  - main view switch:
    - `renderReposView()`
    - `renderPullsView()`
    - `renderIssuesView()`
    - `renderPRDetailView()`
    - `renderSettingsView()`
- Shared UI blocks:
  - `renderRepoNav()`, `renderLoading()`, `renderError()`, `renderDiff()`, `renderAIReview()`

## 2) Design system overview (GitVibe Aurora)

- **Theme direction:** dark-first aurora developer console.
- **Visual language:** glassmorphism cards, frosted panels, cyan/violet/teal accent glow, subtle gradients.
- **Typography:** modern sans for UI with monospace accents for technical metadata.
- **Motion:** lightweight transitions with reduced-motion fallback.
- **Accessibility:** retained keyboard shortcuts and added/kept visible focus states (`:focus-visible`), contrast-safe semantic colors, responsive behavior.
- **Scope of change:** presentation layer only (CSS + non-functional class/markup refinements), no logic/API/auth/routing/demo behavior changes.

## 3) Theme tokens

### Core palette
- `--bg`: base canvas (deep navy)
- `--bg-secondary`, `--bg-tertiary`, `--bg-elevated`, `--bg-glass`: layered panel surfaces
- `--text`, `--text-secondary`: primary and supporting text
- `--accent`, `--accent-hover`, `--accent-violet`, `--accent-teal`: aurora accents
- `--success`, `--warning`, `--danger`, `--info`: semantic states

### Shape, depth, motion
- `--radius-sm`, `--radius`, `--radius-lg`
- `--shadow-soft`, `--shadow-elevated`
- `--transition-fast`, `--transition`

### Typography tokens
- `--font-sans`
- `--font-mono`

### Theme switching
- Dark tokens in `:root`.
- Light-mode overrides in `[data-theme="light"]`.
- Toggle remains controlled by existing `state.theme` + `data-theme` attribute behavior.

## 4) API/Auth/Demo behavior mapping (unchanged)

- API calls remain:
  - `GET /health`
  - `GET /api/auth/status`
  - `GET /api/repos`
  - `GET /api/repos/{owner}/{repo}/pulls`
  - `GET /api/repos/{owner}/{repo}/issues`
  - `POST /api/repos/{owner}/{repo}/pulls/{number}/merge`
  - `POST /api/ai/review/jobs`
  - `GET /api/jobs/{jobId}`
- Auth behavior still runtime-driven (`MockAuthProvider` in demo, backend status in non-demo).
- Demo mode banner and local persisted simulation remain intact.

## 5) Future extension ideas

1. Add density presets (`comfortable`, `compact`) via token sets only.
2. Add user-selectable accent packs (Aurora Cyan/Violet/Teal) using CSS custom properties.
3. Introduce optional high-contrast accessibility theme variant.
4. Add lightweight component animation utility classes for staged UI reveals.
