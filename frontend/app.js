/* GitVibe — Frontend Application
 * Uses runtime-injected API/auth adapters based on APP_MODE.
 */
(function () {
  "use strict";

  // ── State ──────────────────────────────────────────────────────────
  const state = {
    view: "repos",       // repos | pulls | issues | pr-detail | settings
    health: null,
    authStatus: null,
    repos: [],
    pulls: [],
    issues: [],
    selectedRepo: null,  // { owner, name }
    selectedPR: null,
    aiReview: null,
    aiJobId: null,
    loading: {},
    error: null,
    theme: localStorage.getItem("gv-theme") || "dark",
    appMode: "unknown",
  };

  let runtime = null;
  let api = null;

  // ── Toast notifications ────────────────────────────────────────────
  function toast(message, type) {
    type = type || "info";
    var container = document.getElementById("toast-container");
    var el = document.createElement("div");
    el.className = "toast " + type;
    el.textContent = message;
    container.appendChild(el);
    setTimeout(function () { el.remove(); }, 4000);
  }

  function ensureApi() {
    if (!api) throw new Error("Runtime API is unavailable.");
    return api;
  }

  // ── Data Fetching ──────────────────────────────────────────────────
  async function fetchHealth() {
    try {
      state.health = await ensureApi().get("/health");
    } catch (e) {
      state.health = { status: "error", demo_mode: state.appMode === "demo", services: {} };
    }
    render();
  }

  async function fetchAuthStatus() {
    try {
      state.authStatus = await ensureApi().get("/api/auth/status");
    } catch (e) {
      state.authStatus = {
        mode: state.appMode === "demo" ? "demo" : "unknown",
        authenticated: state.appMode === "demo",
      };
    }
    render();
  }

  async function fetchRepos() {
    state.loading.repos = true;
    state.error = null;
    render();
    try {
      var data = await ensureApi().get("/api/repos");
      state.repos = data.repos || [];
    } catch (e) {
      state.error = "Failed to load repositories: " + e.message;
      state.repos = [];
    }
    state.loading.repos = false;
    render();
  }

  async function fetchPulls(owner, repo) {
    state.loading.pulls = true;
    state.error = null;
    render();
    try {
      var data = await ensureApi().get("/api/repos/" + encodeURIComponent(owner) + "/" + encodeURIComponent(repo) + "/pulls");
      state.pulls = data.pull_requests || [];
    } catch (e) {
      state.error = "Failed to load pull requests: " + e.message;
      state.pulls = [];
    }
    state.loading.pulls = false;
    render();
  }

  async function fetchIssues(owner, repo) {
    state.loading.issues = true;
    state.error = null;
    render();
    try {
      var data = await ensureApi().get("/api/repos/" + encodeURIComponent(owner) + "/" + encodeURIComponent(repo) + "/issues");
      state.issues = data.issues || [];
    } catch (e) {
      state.error = "Failed to load issues: " + e.message;
      state.issues = [];
    }
    state.loading.issues = false;
    render();
  }

  async function mergePR(owner, repo, pullNumber, method) {
    try {
      toast("Merging PR #" + pullNumber + "...", "info");
      await ensureApi().post(
        "/api/repos/" + encodeURIComponent(owner) + "/" + encodeURIComponent(repo) + "/pulls/" + pullNumber + "/merge",
        { merge_method: method || "merge" }
      );
      toast("PR #" + pullNumber + " merged!", "success");
      fetchPulls(owner, repo);
    } catch (e) {
      toast("Merge failed: " + e.message, "error");
    }
  }

  async function requestAIReview(owner, repo, pullNumber) {
    state.aiReview = null;
    state.aiJobId = null;
    toast("Starting AI review...", "info");
    render();
    try {
      var data = await ensureApi().post("/api/ai/review/jobs", {
        owner: owner,
        repo: repo,
        pull_number: pullNumber,
      });
      state.aiJobId = data.job && data.job.id;
      if (state.aiJobId) pollAIJob(state.aiJobId);
    } catch (e) {
      toast("AI review failed: " + e.message, "error");
    }
  }

  function pollAIJob(jobId) {
    var interval = setInterval(async function () {
      try {
        var data = await ensureApi().get("/api/jobs/" + jobId);
        var job = data.job;
        if (job.status === "completed") {
          clearInterval(interval);
          state.aiReview = job.result;
          state.aiJobId = null;
          toast("AI review complete!", "success");
          render();
        } else if (job.status === "failed") {
          clearInterval(interval);
          state.aiJobId = null;
          toast("AI review failed: " + (job.error || "unknown"), "error");
          render();
        }
      } catch (e) {
        clearInterval(interval);
        state.aiJobId = null;
      }
    }, 2000);
  }

  // ── Navigation ─────────────────────────────────────────────────────
  function navigate(view, params) {
    state.view = view;
    state.error = null;
    if (params) {
      if (params.repo) state.selectedRepo = params.repo;
      if (params.pr) state.selectedPR = params.pr;
    }
    render();
    if (view === "repos") fetchRepos();
    if (view === "pulls" && state.selectedRepo) {
      fetchPulls(state.selectedRepo.owner, state.selectedRepo.name);
    }
    if (view === "issues" && state.selectedRepo) {
      fetchIssues(state.selectedRepo.owner, state.selectedRepo.name);
    }
  }

  function toggleTheme() {
    state.theme = state.theme === "dark" ? "light" : "dark";
    localStorage.setItem("gv-theme", state.theme);
    document.documentElement.setAttribute("data-theme", state.theme);
    render();
  }

  // ── Rendering ──────────────────────────────────────────────────────
  function h(tag, attrs, children) {
    var el = document.createElement(tag);
    if (attrs) {
      Object.keys(attrs).forEach(function (key) {
        if (key === "className") el.className = attrs[key];
        else if (key === "onclick" || key === "onchange") el[key] = attrs[key];
        else if (key === "innerHTML") el.innerHTML = attrs[key];
        else el.setAttribute(key, attrs[key]);
      });
    }
    if (children) {
      if (typeof children === "string") el.textContent = children;
      else if (Array.isArray(children)) {
        children.forEach(function (c) { if (c) el.appendChild(c); });
      }
    }
    return el;
  }

  function renderHeader() {
    var healthDot = "error";
    if (state.health) {
      healthDot = state.health.status === "ok" ? "ok" : "degraded";
    }

    var modeText = "Loading...";
    if (state.authStatus) {
      modeText = state.authStatus.mode === "demo" ? "DEMO MODE" : "GitHub OAuth";
    }
    if (state.appMode === "demo") modeText = "DEMO MODE";

    return h("header", { className: "app-header" }, [
      h("div", { className: "logo", onclick: function () { navigate("repos"); } }, [
        h("span", null, "🎸"),
        document.createTextNode(" Git"),
        h("span", null, "Vibe"),
      ]),
      h("div", { className: "header-actions" }, [
        h("span", { className: "health-dot " + healthDot, title: "Backend: " + (state.health ? state.health.status : "unknown") }),
        h("span", { className: "badge badge-info" }, modeText),
        h("button", {
          className: "btn btn-sm btn-icon",
          onclick: function () { navigate("settings"); },
          title: "Settings",
        }, "⚙"),
        h("button", {
          className: "btn btn-sm btn-icon",
          onclick: toggleTheme,
          title: "Toggle theme",
        }, state.theme === "dark" ? "☀" : "🌙"),
      ]),
    ]);
  }

  function renderModeBanner() {
    if (state.appMode !== "demo") return null;
    return h("div", { className: "mode-banner" }, [
      h("strong", null, "DEMO MODE"),
      h(
        "span",
        null,
        "Offline simulation is active. Data is stored in this browser and is not connected to backend services."
      ),
    ]);
  }

  function renderLoading(msg) {
    return h("div", { className: "loading-state" }, [
      h("div", { className: "spinner" }),
      h("p", null, msg || "Loading..."),
    ]);
  }

  function renderError(msg) {
    return h("div", { className: "error-banner" }, [
      h("span", null, "⚠"),
      h("span", null, msg),
    ]);
  }

  function renderReposView() {
    var content = [];

    content.push(h("div", { className: "section-header" }, [
      h("h2", { className: "section-title" }, "Repositories"),
      h("button", { className: "btn btn-sm", onclick: fetchRepos }, "↻ Refresh"),
    ]));

    if (state.loading.repos) {
      content.push(renderLoading("Loading repositories..."));
      return h("div", null, content);
    }

    if (state.error) content.push(renderError(state.error));

    if (state.repos.length === 0 && !state.loading.repos) {
      content.push(h("div", { className: "empty-state" }, [
        h("h3", null, "No repositories found"),
        h("p", null, "Connect your GitHub account or enable demo mode."),
      ]));
      return h("div", null, content);
    }

    var list = h("div", { className: "card" });
    state.repos.forEach(function (repo) {
      var owner = repo.owner || repo.full_name && repo.full_name.split("/")[0] || "demo";
      var name = repo.name || repo.full_name && repo.full_name.split("/")[1] || "unknown";
      var item = h("div", { className: "list-item", onclick: function () {
        navigate("pulls", { repo: { owner: owner, name: name } });
      }}, [
        h("div", null, [
          h("div", { className: "list-item-title" }, (owner + "/" + name)),
          h("div", { className: "list-item-meta" }, repo.description || "No description"),
          h("div", { className: "list-item-meta" }, [
            repo.language ? h("span", null, "📄 " + repo.language + "  ") : null,
            h("span", null, "⭐ " + (repo.stars !== undefined ? repo.stars : repo.stargazers_count || 0)),
          ]),
        ]),
      ]);
      list.appendChild(item);
    });
    content.push(list);
    return h("div", null, content);
  }

  function renderRepoNav() {
    if (!state.selectedRepo) return null;
    var repo = state.selectedRepo;
    return h("div", null, [
      h("div", { style: "margin-bottom: 16px" }, [
        h("button", { className: "btn btn-sm", onclick: function () { navigate("repos"); } }, "← Back to repos"),
        h("span", { style: "margin-left: 12px; font-weight: 600; font-size: 18px" }, repo.owner + "/" + repo.name),
      ]),
      h("div", { className: "nav-tabs" }, [
        h("button", {
          className: "nav-tab" + (state.view === "pulls" ? " active" : ""),
          onclick: function () { navigate("pulls"); },
        }, "Pull Requests"),
        h("button", {
          className: "nav-tab" + (state.view === "issues" ? " active" : ""),
          onclick: function () { navigate("issues"); },
        }, "Issues"),
      ]),
    ]);
  }

  function renderPullsView() {
    var content = [renderRepoNav()];

    if (state.loading.pulls) {
      content.push(renderLoading("Loading pull requests..."));
      return h("div", null, content);
    }

    if (state.error) content.push(renderError(state.error));

    if (state.pulls.length === 0) {
      content.push(h("div", { className: "empty-state" }, [
        h("h3", null, "No pull requests"),
        h("p", null, "This repository has no open pull requests."),
      ]));
      return h("div", null, content);
    }

    var list = h("div", { className: "card" });
    state.pulls.forEach(function (pr) {
      var prState = (pr.state || "open").toLowerCase();
      var merged = pr.merged || pr.merged_at;
      var badgeClass = merged ? "badge-merged" : (prState === "closed" ? "badge-closed" : "badge-open");
      var badgeText = merged ? "Merged" : (prState === "closed" ? "Closed" : "Open");

      var item = h("div", { className: "list-item", onclick: function () {
        state.selectedPR = pr;
        state.aiReview = null;
        state.aiJobId = null;
        state.view = "pr-detail";
        render();
      }}, [
        h("div", null, [
          h("div", { className: "list-item-title" }, [
            h("span", { className: "badge " + badgeClass, style: "margin-right: 8px" }, badgeText),
            document.createTextNode("#" + pr.number + " " + pr.title),
          ]),
          h("div", { className: "list-item-meta" },
            "by " + (pr.user || pr.author || "unknown") + " • " + (pr.created_at || "")),
        ]),
      ]);
      list.appendChild(item);
    });
    content.push(list);
    return h("div", null, content);
  }

  function renderIssuesView() {
    var content = [renderRepoNav()];

    if (state.loading.issues) {
      content.push(renderLoading("Loading issues..."));
      return h("div", null, content);
    }

    if (state.error) content.push(renderError(state.error));

    if (state.issues.length === 0) {
      content.push(h("div", { className: "empty-state" }, [
        h("h3", null, "No issues"),
        h("p", null, "This repository has no open issues."),
      ]));
      return h("div", null, content);
    }

    var list = h("div", { className: "card" });
    state.issues.forEach(function (issue) {
      var issueState = (issue.state || "open").toLowerCase();
      var badgeClass = issueState === "closed" ? "badge-closed" : "badge-open";
      var badgeText = issueState === "closed" ? "Closed" : "Open";

      var item = h("div", { className: "list-item" }, [
        h("div", null, [
          h("div", { className: "list-item-title" }, [
            h("span", { className: "badge " + badgeClass, style: "margin-right: 8px" }, badgeText),
            document.createTextNode("#" + issue.number + " " + issue.title),
          ]),
          h("div", { className: "list-item-meta" },
            "by " + (issue.user || issue.author || "unknown") + " • " + (issue.created_at || "")),
        ]),
      ]);
      list.appendChild(item);
    });
    content.push(list);
    return h("div", null, content);
  }

  function renderPRDetailView() {
    var pr = state.selectedPR;
    var repo = state.selectedRepo;
    if (!pr || !repo) return renderError("No PR selected");

    var prState = (pr.state || "open").toLowerCase();
    var merged = pr.merged || pr.merged_at;
    var canMerge = prState === "open" && !merged;

    var content = [];

    // Back button
    content.push(h("div", { style: "margin-bottom: 16px" }, [
      h("button", { className: "btn btn-sm", onclick: function () { navigate("pulls"); } }, "← Back to PRs"),
    ]));

    // PR header card
    var headerCard = h("div", { className: "card" }, [
      h("div", { className: "card-header" }, [
        h("div", null, [
          h("h2", { style: "font-size: 20px; margin-bottom: 4px" },
            "#" + pr.number + " " + pr.title),
          h("div", { className: "list-item-meta" },
            "by " + (pr.user || pr.author || "unknown") + " • " +
            (pr.head_branch || pr.head || "feature") + " → " +
            (pr.base_branch || pr.base || "main")),
        ]),
        h("div", null, [
          h("span", {
            className: "badge " + (merged ? "badge-merged" : prState === "closed" ? "badge-closed" : "badge-open"),
          }, merged ? "Merged" : prState === "closed" ? "Closed" : "Open"),
        ]),
      ]),
      pr.body ? h("p", { style: "font-size: 14px; color: var(--text-secondary); margin-top: 8px" }, pr.body) : null,
    ]);
    content.push(headerCard);

    // Action buttons
    var actions = h("div", { style: "display: flex; gap: 8px; margin-bottom: 16px; flex-wrap: wrap" });

    if (canMerge) {
      actions.appendChild(h("button", {
        className: "btn btn-success",
        onclick: function () { mergePR(repo.owner, repo.name, pr.number, "merge"); },
      }, "✓ Merge"));
      actions.appendChild(h("button", {
        className: "btn btn-sm",
        onclick: function () { mergePR(repo.owner, repo.name, pr.number, "squash"); },
      }, "Squash"));
      actions.appendChild(h("button", {
        className: "btn btn-sm",
        onclick: function () { mergePR(repo.owner, repo.name, pr.number, "rebase"); },
      }, "Rebase"));
    }

    actions.appendChild(h("button", {
      className: "btn btn-primary",
      onclick: function () { requestAIReview(repo.owner, repo.name, pr.number); },
      disabled: !!state.aiJobId,
    }, state.aiJobId ? "⏳ Reviewing..." : "🤖 AI Review"));

    content.push(actions);

    // Diff (from demo data)
    if (pr.diff) {
      content.push(renderDiff(pr.diff));
    }

    // AI Review results
    if (state.aiJobId) {
      content.push(h("div", { className: "card" }, [
        h("div", { className: "card-title", style: "margin-bottom: 12px" }, "🤖 AI Review in progress..."),
        renderLoading("Waiting for AI analysis..."),
      ]));
    } else if (state.aiReview) {
      content.push(renderAIReview(state.aiReview));
    }

    return h("div", null, content);
  }

  function renderDiff(diffText) {
    var block = h("div", { className: "diff-block" });
    block.appendChild(h("div", { className: "diff-header" }, "Changes"));
    var lines = diffText.split("\n");
    lines.forEach(function (line) {
      var cls = "diff-line context";
      if (line.startsWith("+")) cls = "diff-line add";
      else if (line.startsWith("-")) cls = "diff-line remove";
      else if (line.startsWith("@@")) cls = "diff-line context";
      block.appendChild(h("div", { className: cls }, line));
    });
    return block;
  }

  function renderAIReview(review) {
    var card = h("div", { className: "card" });
    card.appendChild(h("div", { className: "card-title", style: "margin-bottom: 12px" }, "🤖 AI Review Results"));

    if (typeof review === "string") {
      card.appendChild(h("div", { style: "white-space: pre-wrap; font-size: 14px" }, review));
      return card;
    }

    if (review.review) {
      var rev = review.review;
      if (rev.summary) {
        card.appendChild(h("p", { style: "margin-bottom: 12px; font-size: 14px" }, rev.summary));
      }
      if (rev.findings && rev.findings.length) {
        rev.findings.forEach(function (f) {
          var severity = (f.severity || "info").toLowerCase();
          card.appendChild(h("div", { className: "ai-finding severity-" + severity }, [
            h("div", { className: "ai-finding-header" }, [
              h("span", { className: "badge badge-" + (severity === "high" ? "closed" : severity === "medium" ? "info" : "open") }, severity.toUpperCase()),
              h("span", null, f.title || f.message || "Finding"),
            ]),
            f.description ? h("div", { className: "ai-finding-body" }, f.description) : null,
            f.file ? h("div", { className: "ai-finding-body", style: "margin-top: 4px; font-family: monospace" }, "📄 " + f.file + (f.line ? ":" + f.line : "")) : null,
          ]));
        });
      }
    } else {
      card.appendChild(h("div", { style: "white-space: pre-wrap; font-size: 14px" }, JSON.stringify(review, null, 2)));
    }

    return card;
  }

  function renderSettingsView() {
    var content = [];
    content.push(h("div", { className: "section-header" }, [
      h("h2", { className: "section-title" }, "Settings"),
      h("button", { className: "btn btn-sm", onclick: function () { navigate("repos"); } }, "← Back"),
    ]));

    var runtimeCard = h("div", { className: "card" });
    runtimeCard.appendChild(h("h3", { style: "font-size: 16px; font-weight: 600; margin-bottom: 12px" }, "Runtime Mode"));
    runtimeCard.appendChild(h("div", { className: "setting-row" }, [
      h("span", { className: "setting-label" }, "APP_MODE"),
      h("span", { className: "setting-value" }, state.appMode),
    ]));
    runtimeCard.appendChild(h("div", { className: "setting-row" }, [
      h("span", { className: "setting-label" }, "Backend Dependency"),
      h("span", { className: "setting-value" }, state.appMode === "demo" ? "Not required" : "Required"),
    ]));
    content.push(runtimeCard);

    // Health status
    var healthCard = h("div", { className: "card" });
    healthCard.appendChild(h("h3", { style: "font-size: 16px; font-weight: 600; margin-bottom: 12px" }, "System Health"));
    if (state.health) {
      var statusRow = h("div", { className: "setting-row" }, [
        h("span", { className: "setting-label" }, "Status"),
        h("span", null, [
          h("span", { className: "health-dot " + (state.health.status === "ok" ? "ok" : "degraded"), style: "margin-right: 6px" }),
          document.createTextNode(state.health.status || "unknown"),
        ]),
      ]);
      healthCard.appendChild(statusRow);
      healthCard.appendChild(h("div", { className: "setting-row" }, [
        h("span", { className: "setting-label" }, "Demo Mode"),
        h("span", { className: "setting-value" }, state.health.demo_mode ? "Enabled" : "Disabled"),
      ]));
      healthCard.appendChild(h("div", { className: "setting-row" }, [
        h("span", { className: "setting-label" }, "AI Provider"),
        h("span", { className: "setting-value" }, state.health.ai_provider || "none"),
      ]));

      if (state.health.services) {
        Object.keys(state.health.services).forEach(function (name) {
          var svc = state.health.services[name];
          healthCard.appendChild(h("div", { className: "setting-row" }, [
            h("span", { className: "setting-label" }, name),
            h("span", null, [
              h("span", { className: "health-dot " + (svc.ok ? "ok" : "error"), style: "margin-right: 6px" }),
              document.createTextNode(svc.detail || ""),
            ]),
          ]));
        });
      }
    } else {
      healthCard.appendChild(h("p", { className: "setting-value" }, "Loading health data..."));
    }
    content.push(healthCard);

    // Auth status
    if (state.authStatus) {
      var authCard = h("div", { className: "card" });
      authCard.appendChild(h("h3", { style: "font-size: 16px; font-weight: 600; margin-bottom: 12px" }, "Authentication"));
      authCard.appendChild(h("div", { className: "setting-row" }, [
        h("span", { className: "setting-label" }, "Mode"),
        h("span", { className: "setting-value" }, state.authStatus.mode),
      ]));
      authCard.appendChild(h("div", { className: "setting-row" }, [
        h("span", { className: "setting-label" }, "Authenticated"),
        h("span", { className: "setting-value" }, state.authStatus.authenticated ? "Yes" : "No"),
      ]));
      authCard.appendChild(h("div", { className: "setting-row" }, [
        h("span", { className: "setting-label" }, "AI Provider"),
        h("span", { className: "setting-value" }, state.authStatus.ai_provider || "—"),
      ]));
      authCard.appendChild(h("div", { className: "setting-row" }, [
        h("span", { className: "setting-label" }, "CSRF Protection"),
        h("span", { className: "setting-value" }, state.authStatus.csrf_protection_enabled ? "Enabled" : "Disabled"),
      ]));
      content.push(authCard);
    }

    // Theme
    var themeCard = h("div", { className: "card" });
    themeCard.appendChild(h("h3", { style: "font-size: 16px; font-weight: 600; margin-bottom: 12px" }, "Preferences"));
    themeCard.appendChild(h("div", { className: "setting-row" }, [
      h("span", { className: "setting-label" }, "Theme"),
      h("button", { className: "btn btn-sm", onclick: toggleTheme },
        state.theme === "dark" ? "Switch to Light" : "Switch to Dark"),
    ]));
    content.push(themeCard);

    // Keyboard shortcuts
    var kbCard = h("div", { className: "card" });
    kbCard.appendChild(h("h3", { style: "font-size: 16px; font-weight: 600; margin-bottom: 12px" }, "Keyboard Shortcuts"));
    var shortcuts = [
      ["r", "Go to Repositories"],
      ["s", "Go to Settings"],
      ["t", "Toggle Theme"],
      ["Esc", "Go Back"],
    ];
    shortcuts.forEach(function (s) {
      kbCard.appendChild(h("div", { className: "setting-row" }, [
        h("kbd", { className: "kbd" }, s[0]),
        h("span", { className: "setting-value" }, s[1]),
      ]));
    });
    content.push(kbCard);

    return h("div", null, content);
  }

  function render() {
    var app = document.getElementById("app");
    app.innerHTML = "";

    app.appendChild(renderHeader());
    if (state.appMode === "demo") app.appendChild(renderModeBanner());

    var main = h("main", { className: "app-main" });

    switch (state.view) {
      case "repos":
        main.appendChild(renderReposView());
        break;
      case "pulls":
        main.appendChild(renderPullsView());
        break;
      case "issues":
        main.appendChild(renderIssuesView());
        break;
      case "pr-detail":
        main.appendChild(renderPRDetailView());
        break;
      case "settings":
        main.appendChild(renderSettingsView());
        break;
      default:
        main.appendChild(renderReposView());
    }

    app.appendChild(main);
  }

  // ── Keyboard shortcuts ─────────────────────────────────────────────
  document.addEventListener("keydown", function (e) {
    if (e.target.tagName === "INPUT" || e.target.tagName === "SELECT" || e.target.tagName === "TEXTAREA") return;
    switch (e.key) {
      case "r":
        navigate("repos");
        break;
      case "s":
        navigate("settings");
        break;
      case "t":
        toggleTheme();
        break;
      case "Escape":
        if (state.view === "pr-detail") navigate("pulls");
        else if (state.view === "pulls" || state.view === "issues") navigate("repos");
        else if (state.view === "settings") navigate("repos");
        break;
    }
  });

  // ── Bootstrap ──────────────────────────────────────────────────────
  async function bootstrap() {
    document.documentElement.setAttribute("data-theme", state.theme);
    try {
      if (!window.GitVibeRuntime || typeof window.GitVibeRuntime.createRuntime !== "function") {
        throw new Error("Runtime layer is unavailable.");
      }
      runtime = await window.GitVibeRuntime.createRuntime();
      api = runtime.api;
      state.appMode = runtime.config.appMode;
      render();

      await fetchHealth();
      await fetchAuthStatus();
      await fetchRepos();
    } catch (e) {
      state.error = "Startup failed: " + e.message;
      state.health = { status: "error", demo_mode: state.appMode === "demo", services: {} };
      state.authStatus = { mode: "unknown", authenticated: false };
      render();
    }
  }

  bootstrap();
})();
