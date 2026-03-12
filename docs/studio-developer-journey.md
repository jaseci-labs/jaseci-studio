# Jaseci Studio: End-to-End Developer Journey Analysis

**Date**: 2026-03-12
**Author**: Enterprise Architect (Product/UX Analysis)
**Status**: Research / Strategic Planning

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Developer Journey Map](#developer-journey-map)
3. [Current Studio Audit](#current-studio-audit)
4. [Competitive Analysis](#competitive-analysis)
5. [Gap Analysis](#gap-analysis)
6. [Prioritized Feature Roadmap](#prioritized-feature-roadmap)
7. [Key UX Principles](#key-ux-principles)

---

## Executive Summary

Jaseci Studio is at an **early but structurally sound** starting point. The architecture decision to build it entirely in Jac (using jac-client for the React frontend) is both a strength and a constraint. It demonstrates Jac's full-stack capability, which is a powerful marketing signal. However, the current feature set is shallow -- each page exists but none goes deep enough to become indispensable.

**The core problem**: Studio currently serves as a *demonstration of Jac's capabilities* rather than a *tool developers cannot live without*. No page provides functionality that is meaningfully better than what a developer gets from `curl`, a terminal, or a JSON viewer.

**The opportunity**: Jac's graph-native paradigm creates unique visualization and debugging needs that NO existing tool addresses. The graph is not an implementation detail in Jac -- it IS the application state. A tool that makes the graph tangible, debuggable, and navigable would be genuinely differentiated.

**Bottom line**: Studio needs to go from "six pages wide, one inch deep" to "three pages wide, one mile deep" on the capabilities that matter most: the Workbench, the Graph Explorer, and a new Observability/Debugging experience that ties them together.

---

## Developer Journey Map

### Stage 1: Discovery ("I heard about Jac")

| Aspect | Current State | Gap |
|--------|--------------|-----|
| Landing page / docs | jaseci.org exists; Jac docs are available | No interactive "try Jac in your browser" experience |
| First impression | `pip install jaclang && jac run hello.jac` works | No guided tutorial within Studio |
| Time to first "wow" | ~10 min if you know Python, longer otherwise | Sandbox could be the "wow" moment but lacks syntax highlighting and inline errors |

**Verdict**: The discovery phase relies entirely on external docs and the CLI. Studio has no role here today. This is acceptable short-term -- the CLI is the correct first touchpoint.

### Stage 2: Learning ("How does this language work?")

| Aspect | Current State | Gap |
|--------|--------------|-----|
| Interactive learning | Sandbox page has 3 templates | No progression, no "next step" guidance, no syntax highlighting |
| Language concepts | Must read external docs | No integrated docs/reference panel |
| Error understanding | Raw `jac run` stderr piped back | No error explanation, no "did you mean?" suggestions |
| Graph mental model | Graph Explorer exists but shows runtime IDs not meaningful labels | New developers cannot connect "I wrote `node Person`" to what appears in the graph |

**Verdict**: The Sandbox is the right vehicle for learning, but it is currently a plain textarea with subprocess execution. It needs to become a proper playground -- think Rust Playground or Go Playground, not Notepad.

### Stage 3: Building ("I'm writing a real app")

| Aspect | Current State | Gap |
|--------|--------------|-----|
| IDE experience | `jac lsp` provides Language Server Protocol support | Studio has no code editing capability beyond the Sandbox textarea |
| Walker development | Workbench discovers walkers and lets you run them | No ability to set breakpoints, step through walker traversal, or see which nodes a walker visited |
| Graph schema design | Must be done in .jac files | No visual schema designer |
| AI integration (by_llm) | Gateway page stores model configs | Configs are stored in Studio's graph, not connected to the actual Jac runtime's model routing |
| Testing | `jac test` in CLI | No test runner UI, no coverage visualization |
| Hot reload | `jac start --dev` provides HMR | Studio does not reflect changes automatically -- must refresh |

**Verdict**: This is the stage where developers spend 80% of their time, and Studio provides almost no value here. The Workbench is useful but primitive. The critical missing piece is **walker execution visualization** -- seeing how a walker traverses the graph in real time, which nodes it visits, what it reports.

### Stage 4: Debugging ("Why doesn't this work?")

| Aspect | Current State | Gap |
|--------|--------------|-----|
| Walker output inspection | Workbench shows JSON result blob | No structured output viewer, no diff between runs |
| Graph state inspection | Graph Explorer shows nodes/props | Cannot edit node properties, cannot manually spawn a walker on a specific node |
| Error diagnosis | Raw error strings | No stack trace visualization, no walker traversal replay |
| State comparison | Not available | Cannot compare graph state before/after a walker run |
| Log viewing | Not available | No log tail, no structured log viewer |

**Verdict**: Debugging is the **biggest gap in the entire Jac ecosystem**. When a walker does not behave as expected, the developer's only recourse is print statements and reading JSON blobs. This is where Studio could provide the most transformative value.

### Stage 5: Deploying ("Ship it to production")

| Aspect | Current State | Gap |
|--------|--------------|-----|
| `jac start --scale` | Works, transparent enterprise features | No deployment wizard in Studio |
| Docker / Helm | Enterprise has Helm charts | No "one-click deploy" from Studio |
| Environment config | Env vars documented in README | No config management UI |
| CI/CD | Must set up manually | No GitHub Actions template generator |

**Verdict**: Deployment is adequately served by CLI + docs for now. A deployment wizard would be nice-to-have but not an adoption driver.

### Stage 6: Operating ("It's in production, now what?")

| Aspect | Current State | Gap |
|--------|--------------|-----|
| Health monitoring | Dashboard shows basic stats | Stats are from Studio's own graph, not the application's actual metrics |
| Observability | Enterprise has Prometheus metrics, structured logging | Studio has no connection to Prometheus/Grafana |
| User management | Enterprise has PostgresUserManager | No user management UI in Studio |
| Multi-tenancy | Enterprise has org CRUD | No org management in Studio (listed as Enterprise tier) |
| Alerting | Not available | No alerting configuration |

**Verdict**: Operations tooling is where the Enterprise tier should shine and where revenue justification is strongest. This is correctly gated behind the Enterprise license.

---

## Current Studio Audit

### Page 1: Dashboard (index.jac) -- Grade: C

**What it does**: Shows aggregate counts (total runs, successes, errors, model count, schedule count) and recent activity.

**Honest assessment**:
- The stats displayed are **Studio's own internal stats**, not the application's production metrics. A developer who has run 3 test walkers sees "3 total runs." This is not useful operational data.
- The "System Info" card shows Python version and PID -- information available from any terminal.
- Quick Actions are just links to other pages.
- The health status badge always shows "healthy" because it only checks the Studio process itself.

**What would make it useful**:
- Show the **application's** graph size (node count by type, edge count by type).
- Show walker execution throughput from the actual server (not just Studio test runs).
- Show memory/cache stats from EnterpriseTieredMemory (L1 hit rate, L2 hit rate, L3 query count).
- Show recent errors from the application, not from Studio.

**Recommendation**: Redesign as an **Application Overview** page, not a Studio self-referential dashboard.

### Page 2: Workbench (workbench.jac) -- Grade: B-

**What it does**: Discovers all walkers via runtime introspection, lets you select one, provide JSON payload, and execute it on root. Shows result and run history.

**Honest assessment**:
- **This is the most useful page in Studio.** Walker discovery via `JacRuntime` introspection is genuinely valuable.
- Parameter display with type annotations and defaults is well done.
- Auto-generated payload templates from walker params save real time.
- The execution model (spawn on root with CallState, drain reports) mirrors the actual server behavior, which is important for correctness.

**Weaknesses**:
- Can only spawn on root -- cannot target a specific node. This is a significant limitation for walkers with `with SomeNode entry` handlers.
- JSON payload editing in a plain textarea is painful for complex payloads.
- Result display is a raw JSON dump with no syntax highlighting.
- No diff between consecutive runs of the same walker.
- No ability to see which nodes the walker visited during traversal.
- Duplicate `except Exception as e` block in `run_walker_test` (lines 319-323 of walkers.jac).

**Recommendation**: Invest heavily here. This is the page most likely to make developers say "I need Studio open while I work."

### Page 3: Graph Explorer (graph.jac) -- Grade: C+

**What it does**: Traverses the graph from root via BFS, filters out Studio internal nodes, displays as indented tree or table, with an inspector panel for selected nodes.

**Honest assessment**:
- The tree view is functional and the indentation-based depth display works.
- Node color assignment by type (hash-based palette) is a good touch.
- The inspector showing children as clickable chips allows navigation.
- Filtering out Studio internal types (StudioRoot, WalkerRun, etc.) is the right call.

**Weaknesses**:
- **No actual graph visualization.** This is a tree view, not a graph view. Graphs have cycles, multiple parents, cross-links. A tree flattening loses the topology that makes Jac graphs powerful.
- Node IDs are Python `id()` values, which are meaningless memory addresses. In jac-scale/Enterprise, these would be UUIDs, but the display does not show human-readable labels.
- Cannot edit node properties from the inspector.
- Cannot spawn a walker on a selected node (this would transform debugging).
- Cannot filter by node type.
- Cannot search for a node by property value.
- Edge types are not well-represented -- the "type" column in the edge table shows the target node type, not the edge archetype name.

**Recommendation**: This page needs the most dramatic transformation. See Gap Analysis for the vision.

### Page 4: Sandbox (sandbox.jac) -- Grade: C

**What it does**: Provides a textarea to write Jac code, executes via `subprocess.run(["jac", "run", ...])`, and shows stdout/stderr.

**Honest assessment**:
- The templates (Hello Walker, Graph Traversal, Stateful Counter) are well-chosen for teaching.
- Session history with clickable restore is useful.
- The `unicode_escape` handling for escaped newlines from the client shows attention to real issues.

**Weaknesses**:
- **No syntax highlighting.** This is the single most impactful missing feature. A plain textarea for code is unacceptable in 2026.
- No autocompletion.
- No inline error markers.
- Execution is via subprocess, which means no access to the running server's graph state. Code runs in an isolated process.
- No way to share a sandbox session (no permalink/share URL).
- The 10-second timeout is hardcoded in the default; 30s max via API.

**Recommendation**: Either invest in making this a proper code editor (Monaco/CodeMirror integration) or deprecate it in favor of pointing developers to VS Code + jac LSP. Half-measures here hurt credibility.

### Page 5: Scheduler (scheduler.jac) -- Grade: D+

**What it does**: CRUD for cron schedule records. Toggle enabled/disabled. Delete.

**Honest assessment**:
- The schedules are **stored only as graph nodes**. There is no actual cron execution engine. The scheduler page creates `Schedule` nodes but nothing ever reads them to actually run walkers on a timer.
- This is essentially a TODO list masquerading as a scheduler.
- The cron expression helper text is useful but there is no validation.
- Walker name is a free-text input, not a dropdown of discovered walkers.

**Weaknesses**:
- **Non-functional.** The core feature (actually running walkers on a schedule) does not exist.
- No integration with system cron, APScheduler, Celery Beat, or any execution engine.
- No run history per schedule.
- No next-run calculation from cron expression.

**Recommendation**: Either build a real scheduler (APScheduler integration is the obvious choice) or remove this page entirely. Showing a "Scheduler" page that does not schedule anything damages trust.

### Page 6: AI Gateway (gateway.jac) -- Grade: C-

**What it does**: CRUD for AI model configurations (name, provider, model_id, API key, temperature, max_tokens). Shows cost summary.

**Honest assessment**:
- The model configuration is stored in Studio's graph, not connected to the Jac runtime's actual model routing (the `by_llm` construct).
- Provider icons (O for OpenAI, A for Anthropic) are a nice UX touch.
- Cost tracking exists but has no data source -- `record_cost` must be called manually.

**Weaknesses**:
- **Disconnected from the runtime.** Configuring a model here does not make it available to `by_llm` calls in application code. This is misleading.
- API keys are stored as strings in the graph. In Enterprise, this is a security concern (keys in the database).
- Cost data must be manually recorded -- there is no automatic instrumentation.
- No model health check ("can I actually reach this model?").
- No request/response logging for LLM calls.

**Recommendation**: This needs to either integrate with the actual Jac model routing infrastructure or be redesigned as a monitoring/proxy layer. Currently it is a disconnected config form.

### Page 7: Layout (layout.jac) -- Grade: B+

**What it does**: Sidebar navigation with route-based active state, logo, version display, server status indicator.

**Honest assessment**:
- Clean, well-organized sidebar with section grouping (Overview / Develop / Configure).
- Active route highlighting with accent bar is visually clear.
- Server running indicator in footer is useful.
- The CSS (studio.css) is comprehensive and well-structured -- dark theme, responsive breakpoints, consistent design tokens.

**Weaknesses**:
- No collapsible sidebar for more screen real estate.
- No breadcrumb trail within pages.
- No global search / command palette (Cmd+K).
- No user context (who is logged in, which org).

**Recommendation**: The layout is the strongest UX element. It provides a professional shell that the page content needs to live up to.

---

## Competitive Analysis

### What Best-in-Class Dev Tools Do

| Tool | Key Strength | What Jac Developers Wish They Had |
|------|-------------|-----------------------------------|
| **Supabase Studio** | Table editor with inline editing, SQL editor with autocomplete, auth UI, realtime subscriptions viewer | Inline node property editing, graph query language with autocomplete |
| **Prisma Studio** | Type-safe data browser, relationship navigation, inline editing | Node/edge browsing with type-safe property editing |
| **Firebase Console** | Realtime data viewer, auth management, function logs, crashlytics | Live graph state updates, walker execution logs |
| **GraphQL Playground / Apollo Studio** | Schema explorer, query builder with autocomplete, query history, tracing per resolver | Walker parameter builder, execution trace per walker hop |
| **Vercel Dashboard** | Deployment logs, preview URLs, analytics, team management | Walker deployment status, execution analytics |
| **Retool** | Drag-and-drop internal tool builder, data source connections | Visual walker pipeline builder |
| **n8n / Windmill** | Visual workflow builder, execution logs per node, error handling UI | Visual agent builder (planned in roadmap) |
| **Grafana** | Dashboards, alerting, log aggregation, trace exploration | Application observability (not just Studio self-metrics) |

### Unique Jac/Graph Opportunities No Competitor Addresses

1. **Walker Traversal Replay**: No tool shows how an autonomous agent traverses a graph. In Jac, walkers visit nodes via `-->` and `visit`. Visualizing the path a walker takes through the graph -- node by node, with the state at each hop -- would be genuinely unprecedented.

2. **Graph Diff**: Showing what changed in the graph before vs. after a walker run. What nodes were created? What edges were added? What properties were mutated? This is analogous to a database diff but for graphs.

3. **Spawn-on-Node Debugging**: The ability to select any node in the graph and spawn a walker on it (not just root) would be a breakthrough debugging tool. Currently, walkers can only be spawned on root from the Workbench.

4. **Ability Graph**: Visualizing which walkers can enter which node types, based on the `with NodeType entry` declarations. This is the equivalent of an API route map but for graph-native applications.

5. **by_llm Tracing**: For agentic applications, showing the LLM call chain -- what prompt was sent, what response came back, how the walker decided to traverse next -- is the killer feature for AI agent debugging.

---

## Gap Analysis

### Critical Gaps (Adoption Blockers)

#### Gap 1: No Walker Execution Visualization
**Impact**: HIGH -- This is the single feature that would differentiate Studio from any competing tool.
**Current state**: Walker runs produce a JSON blob. The developer has no visibility into which nodes were visited, what decisions were made, or where errors occurred.
**Target state**: After running a walker, the Graph Explorer highlights the traversal path. Each visited node shows the walker's state at that point. Errors are pinpointed to the exact node/edge where they occurred.
**Complexity**: MEDIUM -- Requires instrumenting the walker runtime to capture traversal events (node entered, edge traversed, report emitted, error raised). The visualization layer is the Graph Explorer with path highlighting.

#### Gap 2: No Syntax Highlighting in Code Areas
**Impact**: HIGH -- Every code input (Sandbox editor, Workbench payload, code output displays) uses plain `<textarea>` or `<pre>` elements.
**Current state**: Monospace font, dark background, no highlighting.
**Target state**: At minimum, CodeMirror or Monaco integration for the Sandbox. JSON syntax highlighting for payload editors and output displays.
**Complexity**: LOW for output display (CSS-based JSON highlighting), MEDIUM for full editor (requires CodeMirror/Monaco integration via jac-client).

#### Gap 3: Cannot Spawn Walker on Specific Node
**Impact**: HIGH -- Walkers that have `with SomeNode entry` handlers are untestable from Studio unless they also handle Root.
**Current state**: `run_walker_test` always spawns on `ctx.get_root()`.
**Target state**: Graph Explorer has a "Spawn Walker Here" action on each node. Workbench has a "Target Node" selector.
**Complexity**: LOW -- The walker spawn mechanism already supports arbitrary start nodes via `Jac.spawn(walker, target_node)`. The Graph Explorer already has node selection. The wiring is straightforward.

#### Gap 4: Scheduler Does Not Actually Schedule
**Impact**: MEDIUM -- The page exists and sets expectations it cannot fulfill.
**Current state**: CRUD for schedule records with no execution engine.
**Target state**: Either integrate APScheduler to actually execute walkers on cron, or remove the page and document CLI-based cron alternatives.
**Complexity**: MEDIUM for APScheduler integration, NONE for removal.

#### Gap 5: AI Gateway Is Disconnected from Runtime
**Impact**: MEDIUM -- Model configs stored here are not used by `by_llm`.
**Current state**: Isolated config store.
**Target state**: Gateway configs write to the Jac runtime's model registry. Or, Gateway becomes a monitoring view of models already configured in code.
**Complexity**: HIGH -- Requires understanding and modifying the Jac runtime's model dispatch.

### Important Gaps (Differentiation Drivers)

#### Gap 6: No Application Metrics on Dashboard
**Current state**: Dashboard shows Studio's own run counts.
**Target state**: Shows application graph size (node counts by type), walker execution stats from the server, cache hit rates (L1/L2/L3), error rates.
**Complexity**: LOW if connected to Prometheus `/metrics` endpoint. MEDIUM if pulling directly from runtime.

#### Gap 7: No Graph Search or Filtering
**Current state**: Full BFS traversal displayed as flat tree.
**Target state**: Type-based filtering ("show me all Person nodes"), property search ("name contains Alice"), subgraph extraction.
**Complexity**: MEDIUM -- Requires parameterized `inspect_graph` walker or client-side filtering of the full graph payload.

#### Gap 8: No Node Property Editing
**Current state**: Inspector shows properties as read-only JSON.
**Target state**: Inline property editing with type validation and save. Shows "modified" badge until committed.
**Complexity**: MEDIUM -- Requires a new walker like `update_node_props(node_id, props)` and a UI form generator from property types.

#### Gap 9: No Integrated Documentation/Reference
**Current state**: Must leave Studio to read Jac docs.
**Target state**: Inline help panel, context-sensitive docs (hover over a walker parameter to see its type docs), link to relevant Jac docs sections.
**Complexity**: LOW for linking, MEDIUM for inline context-sensitive help.

### Nice-to-Have Gaps (Delight Features)

#### Gap 10: No Command Palette (Cmd+K)
Global keyboard shortcut to search walkers, navigate pages, run actions.

#### Gap 11: No Dark/Light Theme Toggle
Currently hardcoded dark theme. Some developers prefer light themes.

#### Gap 12: No Shareable Sandbox URLs
Cannot share a sandbox session with a colleague.

#### Gap 13: No Visual Agent Builder
Listed in roadmap as planned. An n8n-style flow editor would be compelling but is a large investment.

#### Gap 14: No Eval Runner
Quality evaluation dashboard for LLM-powered walkers. Planned in README.

---

## Prioritized Feature Roadmap

### Tier 0: Fix What's Broken (Week 1-2)

These are not features -- they are credibility repairs.

1. **Remove or disable Scheduler page** until it actually schedules. Replace with a "Coming Soon" card or remove from navigation entirely. A feature that does not work is worse than a feature that does not exist.

2. **Fix duplicate except block** in `run_walker_test` walker (walkers.jac lines 319-323).

3. **Connect Dashboard to real data** or relabel it honestly. Either pull from the application's metrics endpoint or rename stats to "Studio Session Stats" so expectations are set correctly.

### Tier 1: Make the Workbench Indispensable (Week 2-6)

The Workbench is the highest-leverage page. Invest here first.

1. **Spawn on specific node**: Add a "Target Node" field to the Workbench. In Graph Explorer, add a "Spawn Walker Here" context action. Wire to `Jac.spawn(walker, target_node)` instead of always using root.
   - Estimated effort: 3-5 days
   - Impact: Unlocks testing of all walkers, not just root-entry ones

2. **Walker traversal capture**: Instrument walker execution to record which nodes were visited, in what order, and what reports were emitted at each step. Store as a traversal log alongside the result.
   - Estimated effort: 5-8 days
   - Impact: Transforms debugging from "guess what happened" to "see what happened"

3. **JSON syntax highlighting for output**: Use CSS-based JSON pretty-printing with color-coded keys, values, strings, numbers. No external library needed.
   - Estimated effort: 1-2 days
   - Impact: Immediate readability improvement

4. **Parameter form generation**: Instead of a JSON textarea, generate a form with typed inputs from walker parameter annotations. Text inputs for strings, number inputs for ints/floats, toggles for bools, JSON editor for dicts/lists.
   - Estimated effort: 3-5 days
   - Impact: Eliminates JSON syntax errors in payloads

### Tier 2: Make the Graph Explorer Transformative (Week 4-10)

The graph IS the application in Jac. The explorer should be the centerpiece.

1. **Force-directed graph layout**: Replace the tree view (which loses topology) with an actual graph visualization. D3 force-directed layout or a simpler SVG-based approach. Nodes as circles with type labels, edges as lines with arrowheads.
   - Estimated effort: 8-12 days (significant, but this is THE differentiating feature)
   - Impact: Makes the graph tangible. This is the screenshot that sells Jac.

2. **Walker path overlay**: After a walker run (from Workbench), highlight the traversal path on the graph. Animate the walk. Show state at each hop.
   - Estimated effort: 5-8 days (depends on traversal capture from Tier 1)
   - Impact: "I can SEE my agent thinking" -- this is the demo moment

3. **Node type filtering**: Sidebar with checkboxes for each node type. Toggle visibility. Show counts.
   - Estimated effort: 2-3 days
   - Impact: Essential for any graph with more than ~20 nodes

4. **Property search**: Search bar that highlights nodes matching a property filter (e.g., `name == "Alice"` or `age > 30`).
   - Estimated effort: 3-5 days
   - Impact: Find-in-graph is a basic expectation

5. **Inline property editing**: Click a property value in the inspector to edit it. Save writes through the Jac runtime.
   - Estimated effort: 5-7 days
   - Impact: Enables "what if" exploration without restarting

### Tier 3: Make the Sandbox a Real Playground (Week 8-14)

Only invest here after Tiers 1-2 are solid.

1. **CodeMirror integration**: Syntax highlighting, bracket matching, line numbers, basic autocomplete for Jac keywords. CodeMirror 6 is lightweight and works in any framework.
   - Estimated effort: 5-8 days (depends on jac-client's ability to embed third-party JS)
   - Impact: Goes from "embarrassing" to "professional"

2. **Inline error display**: Parse `jac run` stderr and display error markers on the relevant line in the editor.
   - Estimated effort: 3-5 days
   - Impact: Reduces the "run, read error, find line, fix, run" loop

3. **Sandbox graph view**: After running code in the sandbox, show the resulting graph in a mini graph explorer below the output.
   - Estimated effort: 5-8 days
   - Impact: Connects code to its graph output visually

### Tier 4: Enterprise & Operations (Week 12+)

These are correctly gated behind Enterprise licensing.

1. **Application metrics dashboard**: Pull from Prometheus `/metrics` or directly from EnterpriseTieredMemory stats. Show cache hit rates, query latency percentiles, walker throughput, error rates.

2. **User management UI**: List users, create/delete users, assign roles. Wraps PostgresUserManager.

3. **Org/tenant management**: Create/suspend/delete orgs, manage quotas, view per-org usage. Wraps OrgStore.

4. **Audit trail viewer**: Searchable audit log with filters by user, action, timestamp. Wraps the `jaseci.enterprise.audit` logger output.

5. **LLM cost attribution**: Connect to by_llm instrumentation to show real cost data per model, per walker, per user.

### Tier 5: Moonshots (Planned, Not Immediate)

1. **Visual Agent Builder**: n8n-style drag-and-drop flow editor that generates .jac code. This is the biggest investment on the roadmap and should only start after Tiers 1-3 prove Studio's value.

2. **Collaborative editing**: Multiple developers working on the same graph in real time.

3. **Deployment wizard**: One-click deploy to Kubernetes with generated Helm values.

---

## Key UX Principles

### 1. The Graph Is the Application

Every page in Studio should reinforce this mental model. The graph is not a database to be queried -- it is the living state of the application. Nodes are entities, edges are relationships, and walkers are the actors that traverse and transform them. Every UI decision should make this paradigm more tangible.

### 2. Show, Don't Tell

Replace JSON blobs with visual representations wherever possible. A walker traversal path shown on a graph communicates more than 100 lines of JSON output. A colored node with its properties shown inline communicates more than a table row. Studio's value proposition is **making the invisible visible**.

### 3. Depth Over Breadth

It is better to have 3 pages that developers love than 6 pages they tolerate. The current state of 6 shallow pages dilutes the value proposition. Prioritize making the Workbench and Graph Explorer world-class before adding new pages.

### 4. Connect Everything

The Workbench should link to the Graph Explorer (see the result). The Graph Explorer should link to the Workbench (spawn a walker here). The Dashboard should show data from both. Currently, each page is an island. The power of Studio comes from the connections between views, just as the power of Jac comes from the connections between nodes.

### 5. Respect the CLI

Studio should complement the CLI, not replace it. Developers who prefer terminals should never be forced into Studio. Every action available in Studio should also be available via `jac` commands or API calls. Studio adds visualization and exploration -- it does not gatekeep functionality.

### 6. Progressive Disclosure

A new developer should see a clean, simple interface. An experienced developer should be able to access advanced features (property editing, custom spawn targets, traversal replay) without them cluttering the default view. Use expandable sections, keyboard shortcuts, and "advanced" toggles.

### 7. No Fake Features

If a feature does not work, it should not have a page. The Scheduler page and the disconnected AI Gateway erode trust. A "Coming Soon" banner is more honest and more professional than a form that saves data to nowhere.

---

## Appendix: Architecture Observations

### Dual Backend Problem

Studio currently has TWO backend implementations:
1. **Jac walkers** (walkers.jac) -- the primary backend, executed via `jac start` and jac-client
2. **Python FastAPI routes** (src/jaseci_studio/api/routes.py) -- a fallback/standalone mode with an in-memory dict store

These are completely independent. The Python routes use `_store: dict[str, list]` for state, while the Jac walkers use graph nodes. The Python routes have different walker introspection logic (using `WalkerArchitype.__subclasses__()` vs the Jac walker using `Jac.list_walkers()`). The graph inspection logic is different (Python uses `node.__jac__.edges` vs the Jac walker using `[node -->]` operators).

**Recommendation**: Pick one and commit. The Jac walkers should be the canonical backend. The Python routes should be deprecated or converted to thin proxies that spawn the Jac walkers. Maintaining two implementations doubles the maintenance cost and creates behavior divergence.

### jac-client Constraints

Studio is built with jac-client, which compiles Jac `cl {}` blocks to React components. This is powerful for demonstrating Jac's full-stack capability, but it means:
- No access to React ecosystem libraries (CodeMirror, React Flow, D3) without explicit jac-client interop
- CSS is the only styling mechanism (no Tailwind, no CSS-in-JS)
- Component model is limited to what jac-client supports

The force-directed graph visualization (Tier 2) will need to either:
- Use raw SVG/Canvas from within cl{} blocks
- Find a way to integrate a JavaScript visualization library through jac-client's interop layer
- Build a custom lightweight graph renderer in pure CSS/SVG

This is the highest technical risk item on the roadmap and needs a spike/prototype before committing to a timeline.

### Licensing Tier System

The licensing system (utils/licensing.py) is simple and well-designed:
- Free: detects no license
- Pro: detects `JASECI_LICENSE_KEY` env var
- Enterprise: detects `jaseci_enterprise` import

Feature gating is via `has_tier("pro")` / `require_tier("enterprise")` decorators. The README tier table is a good commercial structure. The key insight: **the feature code is open source; the license gates runtime activation.** This is the correct model for building trust while monetizing enterprise features.

### Test Coverage

17 tests across 2 files. All test the Python API routes, none test the Jac walkers. This is a significant gap -- the actual backend (Jac walkers) has zero test coverage.

**Recommendation**: Add walker-level tests that exercise the Jac backend directly. This can use `jac test` with test walkers that spawn the Studio walkers and assert on reports.

---

## Summary of Recommendations (Priority Order)

| Priority | Action | Effort | Impact |
|----------|--------|--------|--------|
| P0 | Remove/disable non-functional Scheduler | 1 day | Trust repair |
| P0 | Fix duplicate except block in run_walker_test | 10 min | Bug fix |
| P1 | Add "Spawn on Node" to Workbench + Graph Explorer | 3-5 days | Unlocks walker testing |
| P1 | Walker traversal capture and display | 5-8 days | Killer debugging feature |
| P1 | JSON syntax highlighting in outputs | 1-2 days | Immediate readability |
| P2 | Force-directed graph visualization | 8-12 days | THE differentiating feature |
| P2 | Walker path overlay on graph | 5-8 days | "See your agent think" |
| P2 | Node type filtering in Graph Explorer | 2-3 days | Essential at scale |
| P2 | Parameter form generation in Workbench | 3-5 days | Eliminates JSON errors |
| P3 | CodeMirror integration for Sandbox | 5-8 days | Professional code editing |
| P3 | Inline error display in Sandbox | 3-5 days | Faster debugging loop |
| P3 | Property search in Graph Explorer | 3-5 days | Find-in-graph |
| P3 | Inline property editing | 5-7 days | "What if" exploration |
| P4 | Application metrics dashboard (Enterprise) | 5-8 days | Operations value |
| P4 | User/org management UI (Enterprise) | 8-12 days | Admin value |
| P5 | Visual Agent Builder | 20-30 days | Moonshot differentiator |

**Total estimated investment for P0-P2 (the "Studio v1.0" that developers would actually want)**: ~30-45 developer-days.

The goal is not to ship everything. The goal is to make three things excellent: the Workbench (test walkers on any node, see what happened), the Graph Explorer (see the graph, see the walker path, navigate and edit), and the cross-linking between them (run a walker from the graph, see the graph from the workbench). Everything else is secondary.
