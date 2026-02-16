/* GitVibe Runtime Composition Layer
 * Provides APP_MODE-driven API/auth/storage adapters.
 */
(function (global) {
  "use strict";

  var VALID_MODES = { demo: true, development: true, production: true };
  var LOCAL_HOSTS = { "": true, localhost: true, "127.0.0.1": true, "::1": true };
  var DEMO_STATE_SCHEMA_VERSION = 1;

  function parseBoolean(value, fallback) {
    if (typeof value === "boolean") return value;
    if (typeof value !== "string") return fallback;
    var normalized = value.trim().toLowerCase();
    if (normalized === "1" || normalized === "true" || normalized === "yes" || normalized === "on") {
      return true;
    }
    if (normalized === "0" || normalized === "false" || normalized === "no" || normalized === "off") {
      return false;
    }
    return fallback;
  }

  function normalizeMode(raw) {
    var candidate = String(raw || "").trim().toLowerCase();
    return VALID_MODES[candidate] ? candidate : "development";
  }

  function deepClone(value) {
    return JSON.parse(JSON.stringify(value));
  }

  function nowIso() {
    return new Date().toISOString();
  }

  function safeDecode(value) {
    try {
      return decodeURIComponent(value);
    } catch (error) {
      return value;
    }
  }

  function randomId(prefix) {
    if (global.crypto && typeof global.crypto.randomUUID === "function") {
      return prefix + "-" + global.crypto.randomUUID();
    }
    return prefix + "-" + Date.now().toString(36) + "-" + Math.random().toString(36).slice(2, 10);
  }

  var DEMO_SEED = Object.freeze({
    repos: [
      {
        id: 101,
        owner: "demo-org",
        name: "platform-api",
        description: "Backend APIs and orchestration workflows.",
        language: "Python",
        stargazers_count: 245
      },
      {
        id: 102,
        owner: "demo-org",
        name: "platform-web",
        description: "Frontend shell for review and merge workflows.",
        language: "JavaScript",
        stargazers_count: 173
      }
    ],
    pullsByRepo: {
      "demo-org/platform-api": [
        {
          number: 42,
          title: "feat: add AI repo insights endpoint",
          author: "copilot-bot",
          state: "open",
          created_at: "2026-02-12T09:12:00Z",
          head_branch: "feature/ai-insights",
          base_branch: "main",
          body: "Adds an endpoint to summarize risky files and review latency.",
          diff:
            "diff --git a/app/main.py b/app/main.py\n" +
            "@@ -12,6 +12,11 @@\n" +
            "+@app.get('/api/repos/{repo}/insights')\n" +
            "+async def repo_insights(repo: str):\n" +
            "+    # TODO: add pagination guards\n" +
            "+    return {'repo': repo}\n"
        },
        {
          number: 44,
          title: "fix: tighten webhook signature validation",
          author: "security-maintainer",
          state: "open",
          created_at: "2026-02-13T14:33:00Z",
          head_branch: "fix/webhook-hardening",
          base_branch: "main",
          body: "Enforces timestamp validation and strict signature checks.",
          diff:
            "diff --git a/app/auth.py b/app/auth.py\n" +
            "@@ -20,7 +20,8 @@\n" +
            "-if not signature:\n" +
            "+if not signature or not timestamp:\n" +
            "     raise HTTPException(status_code=401)\n"
        }
      ],
      "demo-org/platform-web": [
        {
          number: 13,
          title: "chore: improve dashboard loading states",
          author: "frontend-dev",
          state: "open",
          created_at: "2026-02-11T18:20:00Z",
          head_branch: "chore/loading-state",
          base_branch: "main",
          body: "Improves user feedback during data fetches.",
          diff:
            "diff --git a/src/components/dashboard.tsx b/src/components/dashboard.tsx\n" +
            "@@ -1,4 +1,6 @@\n" +
            "+const LoadingState = () => <Spinner />\n" +
            " export default function Dashboard() { ... }\n"
        }
      ]
    },
    issuesByRepo: {
      "demo-org/platform-api": [
        {
          number: 8,
          title: "api: harden OAuth callback validation",
          author: "security-maintainer",
          state: "open",
          created_at: "2026-02-10T10:00:00Z"
        },
        {
          number: 9,
          title: "api: add queue retries for review jobs",
          author: "backend-dev",
          state: "open",
          created_at: "2026-02-09T13:00:00Z"
        }
      ],
      "demo-org/platform-web": [
        {
          number: 3,
          title: "web: improve merge action feedback",
          author: "frontend-dev",
          state: "open",
          created_at: "2026-02-08T08:45:00Z"
        }
      ]
    }
  });

  function buildDemoStateFromSeed() {
    return {
      schema_version: DEMO_STATE_SCHEMA_VERSION,
      seeded_at: nowIso(),
      updated_at: nowIso(),
      repos: deepClone(DEMO_SEED.repos),
      pullsByRepo: deepClone(DEMO_SEED.pullsByRepo),
      issuesByRepo: deepClone(DEMO_SEED.issuesByRepo),
      jobs: {},
      session: null
    };
  }

  function isDemoStateValid(candidate) {
    return !!candidate &&
      typeof candidate === "object" &&
      candidate.schema_version === DEMO_STATE_SCHEMA_VERSION &&
      Array.isArray(candidate.repos) &&
      typeof candidate.pullsByRepo === "object" &&
      typeof candidate.issuesByRepo === "object" &&
      typeof candidate.jobs === "object";
  }

  class MemoryPersistence {
    constructor() {
      this._state = null;
    }

    async read() {
      return this._state ? deepClone(this._state) : null;
    }

    async write(state) {
      this._state = deepClone(state);
    }
  }

  class LocalStoragePersistence {
    constructor(namespace) {
      this._key = namespace + ":demo_state";
      this._memoryFallback = new MemoryPersistence();
    }

    async read() {
      if (!global.localStorage) {
        return this._memoryFallback.read();
      }
      try {
        var raw = global.localStorage.getItem(this._key);
        if (!raw) return null;
        return JSON.parse(raw);
      } catch (error) {
        return this._memoryFallback.read();
      }
    }

    async write(state) {
      if (!global.localStorage) {
        return this._memoryFallback.write(state);
      }
      try {
        global.localStorage.setItem(this._key, JSON.stringify(state));
      } catch (error) {
        await this._memoryFallback.write(state);
      }
    }
  }

  class IndexedDbPersistence {
    constructor(namespace) {
      this._dbName = namespace + "_demo_store";
      this._storeName = "kv";
      this._stateKey = "demo_state";
      this._dbPromise = null;
      this._localFallback = new LocalStoragePersistence(namespace);
    }

    _openDb() {
      if (this._dbPromise) return this._dbPromise;
      var self = this;
      this._dbPromise = new Promise(function (resolve, reject) {
        if (!global.indexedDB) {
          reject(new Error("IndexedDB unavailable."));
          return;
        }
        var request = global.indexedDB.open(self._dbName, 1);
        request.onupgradeneeded = function () {
          var db = request.result;
          if (!db.objectStoreNames.contains(self._storeName)) {
            db.createObjectStore(self._storeName);
          }
        };
        request.onsuccess = function () {
          resolve(request.result);
        };
        request.onerror = function () {
          reject(request.error || new Error("Failed to open IndexedDB."));
        };
      });
      return this._dbPromise;
    }

    async read() {
      try {
        var db = await this._openDb();
        var self = this;
        return await new Promise(function (resolve, reject) {
          var transaction = db.transaction(self._storeName, "readonly");
          var store = transaction.objectStore(self._storeName);
          var request = store.get(self._stateKey);
          request.onsuccess = function () {
            resolve(request.result || null);
          };
          request.onerror = function () {
            reject(request.error || new Error("Failed to read IndexedDB state."));
          };
        });
      } catch (error) {
        return this._localFallback.read();
      }
    }

    async write(state) {
      try {
        var db = await this._openDb();
        var self = this;
        await new Promise(function (resolve, reject) {
          var transaction = db.transaction(self._storeName, "readwrite");
          var store = transaction.objectStore(self._storeName);
          var request = store.put(state, self._stateKey);
          request.onsuccess = function () {
            resolve();
          };
          request.onerror = function () {
            reject(request.error || new Error("Failed to write IndexedDB state."));
          };
        });
      } catch (error) {
        await this._localFallback.write(state);
      }
    }
  }

  async function createPersistence(namespace) {
    var persistence = new IndexedDbPersistence(namespace);
    await persistence.read(); // Warm-up to initialize fallback if needed.
    return persistence;
  }

  class DemoRepository {
    constructor(persistence) {
      this._persistence = persistence;
      this._state = null;
    }

    async init() {
      var loaded = await this._persistence.read();
      if (!isDemoStateValid(loaded)) {
        this._state = buildDemoStateFromSeed();
        await this._persist();
        return;
      }
      this._state = loaded;
    }

    _ensureState() {
      if (!this._state) {
        throw new Error("Demo repository is not initialized.");
      }
    }

    _repoKey(owner, repo) {
      return String(owner || "").toLowerCase() + "/" + String(repo || "").toLowerCase();
    }

    async _persist() {
      this._ensureState();
      this._state.updated_at = nowIso();
      await this._persistence.write(this._state);
    }

    async listRepos() {
      this._ensureState();
      var self = this;
      var repos = this._state.repos.map(function (repo) {
        var key = self._repoKey(repo.owner, repo.name);
        var pulls = self._state.pullsByRepo[key] || [];
        var openPrs = pulls.filter(function (item) {
          return (item.state || "open").toLowerCase() === "open" && !item.merged;
        }).length;
        return Object.assign({}, repo, { open_prs: openPrs });
      });
      return deepClone(repos);
    }

    async listPulls(owner, repo) {
      this._ensureState();
      var key = this._repoKey(owner, repo);
      return deepClone(this._state.pullsByRepo[key] || []);
    }

    async listIssues(owner, repo) {
      this._ensureState();
      var key = this._repoKey(owner, repo);
      return deepClone(this._state.issuesByRepo[key] || []);
    }

    async mergePull(owner, repo, pullNumber, mergedBy, mergeMethod) {
      this._ensureState();
      var key = this._repoKey(owner, repo);
      var pulls = this._state.pullsByRepo[key] || [];
      var target = pulls.find(function (item) {
        return Number(item.number) === Number(pullNumber);
      });
      if (!target) {
        return { merged: false, message: "Pull request not found." };
      }
      if (target.merged || (target.state || "").toLowerCase() === "closed") {
        return { merged: true, message: "Pull request already merged." };
      }
      target.state = "closed";
      target.merged = true;
      target.merged_at = nowIso();
      target.merged_by = mergedBy || "demo-user";
      target.merge_method = mergeMethod || "merge";
      await this._persist();
      return { merged: true, message: "Pull request merged in demo mode." };
    }

    async createReviewJob(owner, repo, pullNumber, focus) {
      this._ensureState();
      var jobId = randomId("demo-job");
      this._state.jobs[jobId] = {
        id: jobId,
        status: "queued",
        owner: owner,
        repo: repo,
        pull_number: Number(pullNumber),
        focus: focus || null,
        created_at: nowIso(),
        result: null,
        error: null
      };
      await this._persist();

      var self = this;
      global.setTimeout(async function () {
        var job = self._state.jobs[jobId];
        if (!job) return;
        job.status = "completed";
        job.completed_at = nowIso();
        job.result = self._buildReviewResult(job.owner, job.repo, job.pull_number, job.focus);
        await self._persist();
      }, 800);

      return deepClone(this._state.jobs[jobId]);
    }

    async getJob(jobId) {
      this._ensureState();
      return deepClone(this._state.jobs[jobId] || null);
    }

    _buildReviewResult(owner, repo, pullNumber, focus) {
      var key = this._repoKey(owner, repo);
      var pulls = this._state.pullsByRepo[key] || [];
      var pull = pulls.find(function (item) {
        return Number(item.number) === Number(pullNumber);
      });
      var findings = [];
      if (pull && pull.diff && pull.diff.indexOf("TODO") !== -1) {
        findings.push({
          severity: "medium",
          title: "Outstanding TODO in changed code",
          description: "Replace TODO markers with explicit validation or follow-up issue references.",
          file: "app/main.py",
          line: 15
        });
      }
      findings.push({
        severity: "low",
        title: "Expand regression coverage",
        description: "Add tests for merge and AI review pathways for this change set.",
        file: "backend/tests",
        line: null
      });
      if (focus) {
        findings.push({
          severity: "info",
          title: "Focus area considered",
          description: "Requested review focus: " + focus,
          file: null,
          line: null
        });
      }
      return {
        review: {
          summary: "Demo AI review for #" + pullNumber + " in " + owner + "/" + repo + ".",
          findings: findings
        }
      };
    }

    async getOrCreateSession() {
      this._ensureState();
      if (!this._state.session) {
        this._state.session = {
          user: "demo-admin",
          role: "admin",
          issued_at: nowIso(),
          token_id: randomId("demo-token")
        };
        await this._persist();
      }
      return deepClone(this._state.session);
    }
  }

  class MockAuthProvider {
    constructor(repository, config) {
      this._repository = repository;
      this._config = config;
    }

    async getAuthStatus() {
      var session = await this._repository.getOrCreateSession();
      return {
        authenticated: true,
        mode: "demo",
        app_mode: this._config.appMode,
        github_app_ready: false,
        rbac_enabled: false,
        csrf_protection_enabled: false,
        token_rotation_enabled: false,
        ai_provider: "mock-ai",
        user: session.user,
        role: session.role
      };
    }
  }

  class RealAuthProvider {
    async getAuthStatus() {
      return {
        authenticated: false,
        mode: "github_app_oauth",
        app_mode: "development"
      };
    }
  }

  class HttpApiClient {
    constructor(baseUrl) {
      this._baseUrl = String(baseUrl || "").replace(/\/$/, "");
    }

    _normalizePath(path) {
      var value = String(path || "/");
      if (value.startsWith("http://") || value.startsWith("https://")) return value;
      if (!value.startsWith("/")) value = "/" + value;
      if (this._baseUrl) return this._baseUrl + value;
      return value;
    }

    async get(path) {
      var url = this._normalizePath(path);
      var response = await global.fetch(url);
      if (!response.ok) {
        var body = await response.json().catch(function () {
          return { detail: response.statusText };
        });
        throw new Error(body.detail || ("HTTP " + response.status));
      }
      return response.json();
    }

    async post(path, body) {
      var url = this._normalizePath(path);
      var response = await global.fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body || {})
      });
      if (!response.ok) {
        var payload = await response.json().catch(function () {
          return { detail: response.statusText };
        });
        throw new Error(payload.detail || ("HTTP " + response.status));
      }
      return response.json();
    }
  }

  class MockApiClient {
    constructor(repository, authProvider, config) {
      this._repository = repository;
      this._authProvider = authProvider;
      this._config = config;
    }

    _normalizePath(path) {
      var value = String(path || "/");
      if (!value.startsWith("/")) value = "/" + value;
      value = value.split("?")[0];
      if (value.length > 1 && value.endsWith("/")) value = value.slice(0, -1);
      return value;
    }

    async get(path) {
      var normalized = this._normalizePath(path);
      if (normalized === "/health") {
        return {
          status: "ok",
          demo_mode: true,
          app_mode: this._config.appMode,
          ai_provider: "mock-ai",
          services: {}
        };
      }
      if (normalized === "/api/auth/status") {
        return this._authProvider.getAuthStatus();
      }
      if (normalized === "/api/repos") {
        return { repos: await this._repository.listRepos() };
      }

      var pullsMatch = normalized.match(/^\/api\/repos\/([^/]+)\/([^/]+)\/pulls$/);
      if (pullsMatch) {
        return {
          pull_requests: await this._repository.listPulls(
            safeDecode(pullsMatch[1]),
            safeDecode(pullsMatch[2])
          )
        };
      }

      var issuesMatch = normalized.match(/^\/api\/repos\/([^/]+)\/([^/]+)\/issues$/);
      if (issuesMatch) {
        return {
          issues: await this._repository.listIssues(
            safeDecode(issuesMatch[1]),
            safeDecode(issuesMatch[2])
          )
        };
      }

      var jobMatch = normalized.match(/^\/api\/jobs\/([^/]+)$/);
      if (jobMatch) {
        var job = await this._repository.getJob(safeDecode(jobMatch[1]));
        if (!job) throw new Error("Job not found.");
        return { job: job };
      }

      throw new Error("Mock route not implemented: GET " + normalized);
    }

    async post(path, body) {
      var normalized = this._normalizePath(path);
      var mergeMatch = normalized.match(/^\/api\/repos\/([^/]+)\/([^/]+)\/pulls\/(\d+)\/merge$/);
      if (mergeMatch) {
        return this._repository.mergePull(
          safeDecode(mergeMatch[1]),
          safeDecode(mergeMatch[2]),
          Number(mergeMatch[3]),
          "demo-admin",
          body && body.merge_method ? body.merge_method : "merge"
        );
      }

      if (normalized === "/api/ai/review/jobs") {
        var payload = body || {};
        var job = await this._repository.createReviewJob(
          payload.owner || "demo-org",
          payload.repo || "platform-api",
          Number(payload.pull_number || 1),
          payload.focus || null
        );
        return { job: { id: job.id, status: job.status, created_at: job.created_at } };
      }

      throw new Error("Mock route not implemented: POST " + normalized);
    }
  }

  function loadRuntimeConfig() {
    var injected = global.__GITVIBE_RUNTIME_CONFIG__ || {};
    return Object.freeze({
      appMode: normalizeMode(injected.APP_MODE),
      apiBaseUrl: String(injected.API_BASE_URL || ""),
      demoNamespace: String(injected.DEMO_NAMESPACE || "gitvibe_demo_v1"),
      allowDemoOnPublicHost: parseBoolean(injected.ALLOW_DEMO_ON_PUBLIC_HOST, false)
    });
  }

  function enforceDemoModeSafety(config) {
    if (config.appMode !== "demo") return;
    var hostname = String((global.location && global.location.hostname) || "").toLowerCase();
    if (!LOCAL_HOSTS[hostname] && !config.allowDemoOnPublicHost) {
      throw new Error(
        "APP_MODE=demo is blocked on non-local hosts. " +
        "Set ALLOW_DEMO_ON_PUBLIC_HOST=true only for controlled demos."
      );
    }
  }

  async function createRuntime() {
    var config = loadRuntimeConfig();
    enforceDemoModeSafety(config);

    if (config.appMode === "demo") {
      var persistence = await createPersistence(config.demoNamespace);
      var repository = new DemoRepository(persistence);
      await repository.init();
      var authProvider = new MockAuthProvider(repository, config);
      return {
        config: config,
        api: new MockApiClient(repository, authProvider, config),
        auth: authProvider,
        storage: repository
      };
    }

    return {
      config: config,
      api: new HttpApiClient(config.apiBaseUrl),
      auth: new RealAuthProvider(),
      storage: null
    };
  }

  global.GitVibeRuntime = Object.freeze({
    createRuntime: createRuntime,
    loadRuntimeConfig: loadRuntimeConfig
  });
})(window);
