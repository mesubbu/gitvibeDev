# Moltworker Conversational Platform - Architecture & Implementation Plan

Here is a comprehensive, production-ready architecture and implementation plan for the **Moltworker Conversational Platform** on the Cloudflare ecosystem. 

This design strictly adheres to the principle of **Reversibility**: the AI agent serves solely as an intelligent translation layer between natural language and your canonical Canonical APIs, wrapped in a UI-block communication protocol.

---

### 1️⃣ HIGH-LEVEL ARCHITECTURE

The architecture creates an absolute physical and logical boundary between the Agent Layer and the Business Logic Layer. Moltworker operates as a **presentation and orchestration proxy**, not a backend.

**ASCII Architecture Diagram**
```text
                             ┌───────────────────────┐
                             │    User Application   │
                             │ (Web / Mobile / PWA)  │
                             └──────────┬────────────┘
                                        │ (HTTPS / WebSockets)
                                        ▼ 
┌─────────────────────────────────────────────────────────────────────────────┐
│                      Cloudflare Edge (Moltworker Layer)                     │
│                                                                             │
│  ┌────────────────┐     ┌───────────────────────┐     ┌──────────────────┐  │
│  │ KV (Short-term │     │ Durable Objects (DO)  │     │ LLM Routing Node │  │
│  │ Rate/Budgeting)│     │ (Conversation State & │────▶│ (CF AI / Custom /│  │
│  └────────────────┘     │  Concurrency Control) │     │  Claude / GPT)   │  │
│                         └──────────┬────────────┘     └──────────────────┘  │
│                                    │ (Parsed Intent + Context)              │
│                                    ▼                                        │
│                         ┌───────────────────────┐                           │
│                         │  Command Dispatcher   │                           │
│                         │ (Maps Intent -> RPC)  │                           │
│                         └──────────┬────────────┘                           │
└────────────────────────────────────┼────────────────────────────────────────┘
                                     │ 
                 (Service Bindings / Internal Fetch - JWT Passed)
                                     ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                      Cloudflare Edge (Canonical APIs)                       │
│                                                                             │
│  ┌────────────────┐     ┌───────────────────────┐     ┌──────────────────┐  │
│  │  Auth & RBAC   │────▶│    Business Logic     │────▶│ D1 / R2 / KV     │  │
│  │  Middleware    │     │  (REST / tRPC / RPC)  │     │ (Persistence)    │  │
│  └────────────────┘     └───────────────────────┘     └──────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Security Boundaries:**
1. **Edge Entry**: Validates user session/JWT before DO instantiation.
2. **DO to LLM**: Strips PII, wraps prompt with system instructions.
3. **Dispatcher to Canonical API**: **CRITICAL BOUNDARY**. The Dispatcher calls the internal APIs using Cloudflare Service Bindings natively passing the user's JWT. The API treats the Agent exactly like a classic web frontend.

---

### 2️⃣ CANONICAL API LAYER (SOURCE OF TRUTH)

All business logic lives inside a standalone Worker (e.g., using Hono or standard CF router). 

**Design Principles:**
* The API does **not** know what "Moltworker" is.
* Every request requires a valid JWT.
* Validation is strictly enforced using `zod`.

**Example Canonical API Structure:**
```typescript
// api-worker/src/index.ts
import { Hono } from 'hono';
import { verifyJwt, requireRole } from './middleware/auth';
import { zValidator } from '@hono/zod-validator';
import { ListingSchema } from '@shared/schemas';

const app = new Hono<{ Bindings: Env }>();

app.use('*', verifyJwt());

app.post(
  '/api/v1/listings',
  requireRole(['member', 'vendor']),
  zValidator('json', ListingSchema),
  async (c) => {
    const data = c.req.valid('json');
    const userId = c.get('userId');
    
    // DB Execution
    const result = await c.env.D1.prepare(
      `INSERT INTO listings (id, user_id, title, price, status) VALUES (?1, ?2, ?3, ?4, 'active')`
    ).bind(crypto.randomUUID(), userId, data.title, data.price).run();

    return c.json({ success: true, listingId: result.meta.last_row_id });
  }
);

export default app;
```

---

### 3️⃣ INTENT → COMMAND → ACTION DESIGN

This is a deterministic pipeline. The LLM does not write database queries; it outputs a strict JSON intent corresponding to an allowed command.

**1. Intent Schema (LLM Output)**
```json
{
  "intent_id": "CREATE_LISTING_V1",
  "confidence": 0.96,
  "requires_confirmation": false,
  "parameters": {
    "title": "Vintage Mechanical Keyboard",
    "category": "electronics",
    "price": 120
  }
}
```

**2. Command Dispatcher (Moltworker DO)**
Maps the Intent to a Command structure, injecting the API route and method.
```json
{
  "command": "listings.create",
  "endpoint": "POST /api/v1/listings",
  "payload": {
    "title": "Vintage Mechanical Keyboard",
    "category": "electronics",
    "price": 120
  },
  "auth_token": "ey..." // Injected from DO session
}
```

**Anti-Hallucination Safeguards:**
1. **Strict Output Parsing**: Use `zod` to parse the LLM output. If it fails, auto-prompt the LLM with the error for immediate correction (invisible to user).
2. **Allowed Command Registry**: The Agent context window only receives schemas for commands the user has RBAC permissions to execute. (e.g., A 'Member' never sees the `DELETE_USER` schema).

---

### 4️⃣ STRUCTURED UI BLOCK PROTOCOL

The Agent responds with standard JSON UI blocks. The frontend (Flutter/React/PWA) simply iterates over these blocks and renders native components.

**Response Protocol Schema:**
```json
{
  "response_id": "req-1234",
  "conversation_status": "awaiting_input",
  "agent_message": "I've drafted your new listing. Does this look right?",
  "ui_blocks": [
    {
      "id": "block-1",
      "type": "card",
      "data": {
        "title": "Vintage Mechanical Keyboard",
        "subtitle": "$120.00 - Electronics"
      }
    },
    {
      "id": "block-2",
      "type": "action_row",
      "actions": [
        { "label": "Publish", "command": "CONFIRM_LISTING", "style": "primary" },
        { "label": "Edit Details", "command": "EDIT_LISTING", "style": "secondary" }
      ]
    }
  ]
}
```

**Why this works for Reversibility**: The PWA's component library (`<ListingCard />`, `<ActionRow />`) is identical whether rendering standard REST payloads or Moltworker UI Blocks.

---

### 5️⃣ CONVERSATION MEMORY & STATE

Managing memory safely without blowing up token limits:

1. **Durable Objects (The Brain)**: Manages active conversational state for a specific user session. Keeps the last *N* turns in memory arrays to pass to the LLM.
2. **KV (Short-term cache)**: Caches embeddings, repetitive UI blocks, and LLM budget rates.
3. **D1 (Long-term)**: Saves the transcript asynchronously via `ctx.waitUntil()` for auditing and history.

**Context Trimming Strategy:**
* **Windowing**: Retain the system prompt + last 5 turns.
* **Summarization**: When turns > 5, D1 triggers an async background worker to summarize older turns into a single "Context Block", freeing tokens.
* **PII Isolation**: Regex filters or lightweight classification models scrub PII before sending contexts to external models (if used).

---

### 6️⃣ ROLE-BASED ACCESS CONTROL (RBAC)

**Core Rule: The LLM assigns NO permissions.**

When the user connects to Moltworker via WebSocket/HTTPS:
1. Standard JWT is decoded by the Cloudflare edge.
2. The user's role (`Member`, `Vendor`, `Admin`) is extracted.
3. **Agent Scope Construction**: The agent's system prompt is dynamically assembled. 
   * *If Admin*: "You are an admin assistant. You are capable of [sys.delete_store, sys.ban_user]..."
   * *If Member*: "You are a member assistant. You are capable of [user.search, user.create_listing]..."
4. **Backend Enforcement**: Even if the LLM hallucinates an `Admin` command for a `Member`, the Canonical API Worker will reject the JWT with `403 Forbidden`.

---

### 7️⃣ SECURITY & GUARDRAILS

* **Prompt Injection Defense**: Wrap all user inputs in an explicit delimiter boundary (e.g., `<user_input>{text}</user_input>`) and instruct the model that content inside these tags cannot alter system instructions.
* **Sandboxing**: API Service bindings ensure the Agent Worker cannot access the D1 Database directly. It *must* go through the API Worker via HTTP-like `env.API.fetch()`.
* **Cross-Session Leakage**: Impossible by design because Durable Objects are partitioned strictly by `userId` or `sessionId`.

---

### 8️⃣ FAILURE MODES & RECOVERY

* **Ambiguous Intent**: If the LLM confidence is < 85%, the model outputs `intent: "CLARIFY"`. UI Block renders: "Did you mean creating a new listing or editing an existing one?"
* **API Failure / Timeout**: Catch standard HTTP errors from canonical APIs.
  * Agent receives `500`.
  * Agent says: "Sorry, I ran into a system error while trying to do that. I've logged the issue." (Rollback is inherent. If the DB didn't commit, no state changed).
* **Double Submissions**: All action intents inject an Idempotency-Key (`c.req.header('Idempotency-Key')` in the canonical API).

---

### 9️⃣ END-TO-END EXAMPLES

#### A. Create Listing
1. **User**: "I want to sell my old bike for $200."
2. **LLM Output (Internal)**: `{ "intent_id": "DRAFT_LISTING", "params": { "title": "Old Bike", "price": 200 } }`
3. **Command**: App calls `POST /api/listings/draft` with JWT.
4. **API Action**: Inserts row `status = 'draft'`. Returns ID `lst_123`.
5. **UI Block (To User)**: Renders a `form` block pre-filled with the bike info, with a "Publish" button. 

#### B. Show Dashboard
1. **User**: "Show me my stats."
2. **LLM Output**: `{ "intent_id": "VIEW_DASHBOARD" }`
3. **Command**: `GET /api/users/me/dashboard` (Fetches stats metrics).
4. **UI Block (To User)**: Renders `metrics_grid` layout with views, sales, messages.

#### C. Deactivate Second Listing
1. **User**: "Deactivate the second listing we just talked about."
2. **Context Resolution (DO)**: DO looks at memory array, resolves "second listing" to `lst_456`.
3. **LLM Output**: `{ "intent_id": "UPDATE_LISTING_STATUS", "params": { "id": "lst_456", "status": "inactive" } }`
4. **API Action**: `PATCH /api/listings/lst_456` with `{ "status": "inactive" }`.
5. **UI Block (To User)**: Renders `alert_success` block.

---

### 🔁 10️⃣ REVERSIBILITY & EXIT STRATEGY (CRITICAL)

The requirement to pull the plug on AI without breaking the system is solved by **Dual-Routing**.

**Architecture of Reversibility**:
* The UI PWA has a config: `const APP_MODE = 'conversational' | 'classic';`
* **Classic Mode**: Pressing "New Listing" routes to `/listing/new`. A standard React/Vue form is rendered. Submitting fires `POST /api/listings`.
* **Conversational Mode**: Pressing "New Listing" opens the chat. The user types. The agent figures out the intent and fires *the exact same* `POST /api/listings`.

**Decommission Procedure (Under 10 minutes)**:
1. Change Cloudflare KV pair: `{"agent_ui_enabled": false}`.
2. The PWA checks this on load and entirely hides the chat bubble/agent view.
3. Fallback standard navigation kicks in. The Canonical APIs are untouched because they were never AI-dependent. 

---

### 11️⃣ SCALABILITY & COST CONTROL

* **Edge Scaling**: Because AI is invoked from Workers, it scales instantly to 0 and scales globally without cold starts (Workers run V8 isolates).
* **LLM Batching**: Use Cloudflare AI's built-in inference batching for processing non-urgent text classification.
* **Caching**: Cache identical embedding requests (e.g., standard category searches) in Cloudflare Cache API or KV based on SHA-256 of the prompt.

---

### 12️⃣ PRODUCTION FOLDER STRUCTURE

**Monorepo (Turborepo or Nx recommended)**:
```text
/
├── apps/
│   ├── pwa/                 # Classic UI + conversational renderer
│   ├── api-worker/          # Canonical source of truth APIs (Hono + D1)
│   └── moltworker/          # Agent orchestration & Durable Objects
├── packages/
│   ├── schemas/             # Zod schemas shared between UI, API, and Agent
│   ├── ui-blocks/           # JSON UI protocol definitions
│   └── database/            # D1 migration files & edge ORM definitions
└── wrangler.toml            # Cross-service CF configurations
```

---

### 💰 13️⃣ LLM ROUTING, COST CONTROL & OPTIMIZATION

This is a **mission-critical component**. We build a `LLMRouter` class that orchestrates the fallback strategy entirely within the Edge Worker.

**Dynamic Router Implementation (TypeScript for CF Workers):**

```typescript
export class LLMRouter {
  constructor(private env: Env, private userId: string) {}

  async generate(prompt: string, policy: RoutingPolicy) {
    // 1. Check free tier availability
    if (await this.canUseFreeNeurons(policy)) {
      try {
        return await this.env.AI.run('@cf/meta/llama-3-8b-instruct', { prompt });
      } catch (e) {
        console.warn('CF Free Tier failed, falling back...');
      }
    }

    // 2. Self-Hosted Fallback (If configured)
    if (this.env.SELF_HOSTED_URL) {
      try {
        const res = await fetch(this.env.SELF_HOSTED_URL, { /* payload */ });
        if (res.ok) return await res.json();
      } catch (e) { /* Fall through */ }
    }

    // 3. Paid CF Neurons / Claude / GPT (requires budget)
    if (await this.hasPaidBudget(this.userId)) {
      return await this.callPremiumModel(prompt);
    }

    // 4. Graceful Degradation
    return {
      error: "budget_exhausted",
      ui_blocks: [{ type: "alert", data: { message: "AI services are temporarily busy. Please use the classic navigation menus." }}]
    };
  }

  // Budget validation using KV (Fast, eventually consistent)
  private async hasPaidBudget(userId: string): Promise<boolean> {
    const dailySpend = await this.env.KV.get(`budget:user:${userId}:today`);
    return parseFloat(dailySpend || '0') < 0.50; // Hard cap 50 cents/day/user
  }
}
```

**Usage Monitoring Strategy:**
* **KV**: Counters for immediate rate limits (e.g., max 10 requests/minute).
* **Durable Object / Analytics Engine**: Write token usage asynchronously into Cloudflare Analytics Engine (costs pennies for millions of writes) to calculate aggregated daily/monthly costs without blocking user requests.

**Policy Engine Configurations (Stored in KV):**
```json
{
  "system_mode": "adaptive", // "adaptive", "forced_free", "emergency_stop"
  "role_limits": {
    "member": { "max_daily_cost": 0.10, "premium_allowed": false },
    "vendor": { "max_daily_cost": 0.50, "premium_allowed": true },
    "admin":  { "max_daily_cost": 5.00, "premium_allowed": true }
  }
}
```

**Safety Overrides**: If the LLM routing layer completely breaks, the frontend catches the `503 Service Unavailable`, hides the messaging input, and displays: *"Our smart assistant is taking a break. You can still use the app normally!"* exposing the standard hamburger menu and UI features.
