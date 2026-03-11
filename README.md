# Jaseci Studio

Developer workbench for building, testing, and operating [Jac](https://github.com/jaseci-labs/jaseci) applications. Built entirely in Jac using [jac-client](https://github.com/jaseci-labs/jaseci) for the full-stack experience — backend walkers and frontend UI in one language.

## Architecture

```
┌─────────────────────────────────────────────────┐
│  Jaseci Studio (this repo, OSS)                 │
│  Workbench · Dashboard · AI Gateway · Scheduler │
├─────────────────────────────────────────────────┤
│  jaseci-enterprise (optional, commercial)       │
│  Multi-org · RBAC · Audit · ACL · SSO           │
├─────────────────────────────────────────────────┤
│  jac-scale (OSS)                                │
│  PostgreSQL · Redis · Auth · Admin              │
├─────────────────────────────────────────────────┤
│  jaclang (OSS) + jac-client                     │
│  Compiler · Runtime · CLI · Full-stack UI       │
└─────────────────────────────────────────────────┘
```

## Feature Tiers

| Feature | Free | Pro | Enterprise |
|---------|:----:|:---:|:----------:|
| Walker Workbench (test, inspect, debug) | x | x | x |
| Dashboard (local metrics, health) | x | x | x |
| Sandbox execution | x | x | x |
| AI Gateway (single model) | x | x | x |
| Cron/Webhook triggers | x | x | x |
| Graph Explorer (visual node/edge browser) | | x | x |
| AI Gateway (multi-model routing) | | x | x |
| LLM cost tracking & budgets | | x | x |
| Eval Runner dashboard (history, trends) | | x | x |
| Deployment templates (Helm, GitHub Actions) | | x | x |
| Multi-org dashboard | | | x |
| SSO-gated access | | | x |
| Per-org spend limits & chargeback | | | x |
| Audit trail UI | | | x |
| Custom eval authoring UI | | | x |

**Free** = jaclang + jac-scale (OSS).
**Pro/Enterprise** = requires [jaseci-enterprise](https://github.com/jaseci-labs/jaseci-enterprise) with a valid license key.

## Quick Start

```bash
pip install jaseci-studio
cd jaseci-studio
jac start --dev
# -> http://localhost:8001/
```

## Development

```bash
git clone https://github.com/jaseci-labs/jaseci-studio
cd jaseci-studio
pip install -e ".[dev]"
jac start --dev
```

## Project Structure

```
jaseci-studio/
├── jac.toml                 # jac-client project config
├── main.jac                 # Entry point: includes models + walkers, defines cl { app() }
├── models.jac               # Jac: graph nodes (StudioRoot, WalkerRun, ModelConfig, etc.)
├── walkers.jac              # Jac: all backend walkers (:pub endpoints)
├── pages/                   # jac-client file-based routing (frontend)
│   ├── layout.jac           # Root layout with sidebar navigation
│   ├── index.jac            # Dashboard (/)
│   ├── workbench.jac        # Walker testing (/workbench)
│   ├── graph.jac            # Graph explorer (/graph)
│   ├── gateway.jac          # AI model config (/gateway)
│   ├── scheduler.jac        # Cron/webhook management (/scheduler)
│   └── sandbox.jac          # Jac code execution (/sandbox)
├── styles/
│   └── studio.css           # Dark-theme CSS
├── src/jaseci_studio/       # Python (minimal — plugin + licensing only)
│   ├── plugin.py            # mount_studio() for embedding in existing servers
│   ├── api/routes.py        # FastAPI fallback routes (standalone mode)
│   └── utils/licensing.py   # Tier detection and feature gating
├── pyproject.toml
└── tests/
```

**Code split: ~85% Jac / ~15% Python.**

## Walker Endpoints

All walkers are `:pub` and become HTTP endpoints via `jac start`:

| Walker | Description |
|--------|-------------|
| `init_studio` | Bootstrap Studio subgraph |
| `get_dashboard` | Aggregated stats |
| `get_health` | Runtime health info |
| `list_walkers` | Available walker types |
| `run_walker_test` | Execute a walker |
| `get_run_history` | Run history |
| `inspect_graph` | Graph structure for visualization |
| `add_model` / `list_models` / `remove_model` | AI model CRUD |
| `record_cost` / `get_cost_summary` | LLM cost tracking |
| `create_schedule` / `list_schedules` / `toggle_schedule` / `delete_schedule` | Schedule CRUD |
| `run_sandbox` / `get_sandbox_history` | Code execution |

## Roadmap

| Feature | Status |
|---------|--------|
| Walker Workbench | Done |
| Dashboard with stats | Done |
| Graph Explorer | Done |
| AI Gateway (model CRUD) | Done |
| Scheduler (cron jobs) | Done |
| Sandbox (code execution) | Done |
| Visual Agent Builder (n8n-style flow editor) | Planned |
| Eval Runner (quality evaluation dashboard) | Planned |
| Deployment Manager (Helm, GitHub Actions) | Planned |
| Observability (traces, logs, latency charts) | Planned |
| Multi-org dashboard (Enterprise) | Planned |

### Visual Agent Builder (planned)

An n8n-style drag-and-drop flow editor for building Jac agent pipelines visually. Uses React Flow for the canvas and generates native `.jac` code from the visual graph. Key capabilities:

- **Node palette**: walker, LLM (by_llm), decision, transform, trigger
- **Live preview via HMR**: flow changes write `.jac` files, `jac start --dev` hot-reloads instantly
- **Execution visualization**: highlight flow paths after walker runs
- **Portable output**: generated Jac code runs natively without the builder

## License

MIT License. See [LICENSE](LICENSE) for details.

Pro and Enterprise features require a [jaseci-enterprise](https://github.com/jaseci-labs/jaseci-enterprise) license key. The feature code is open source — the license gates runtime activation.
