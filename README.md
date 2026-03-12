# Jaseci Studio

Developer workbench for building, testing, and operating [Jac](https://github.com/jaseci-labs/jaseci) applications. Built entirely in Jac using [jac-client](https://github.com/jaseci-labs/jaseci) for the full-stack experience — backend walkers and frontend UI in one language.

## Architecture

```
┌─────────────────────────────────────────────────┐
│  Jaseci Studio (this repo, OSS)                 │
│  Workbench · Dashboard · Graph · Packages       │
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
| Dashboard (stats, health, quick actions) | x | x | x |
| Walker Workbench (test, inspect, graph diff) | x | x | x |
| Graph Explorer (force layout, tree, inline edit) | x | x | x |
| Packages (browse & install jacpacks) | x | x | x |
| Server Logs (level filtering, live view) | x | x | x |
| Example App (one-click sample Todo) | x | x | x |
| AI Gateway (model monitoring) | x | x | x |
| Playground (JacBuilder redirect) | x | x | x |
| Walker traversal replay | | x | x |
| Visual Agent Builder (n8n-style flow) | | x | x |
| LLM cost tracking & budgets | | x | x |
| Eval Runner (history, trends) | | x | x |
| Deployment templates (Helm, GitHub Actions) | | x | x |
| Multi-org dashboard | | | x |
| SSO-gated access | | | x |
| Per-org spend limits & chargeback | | | x |
| Audit trail UI | | | x |
| User / tenant management UI | | | x |

**Free** = jaclang + jac-scale (OSS).
**Pro/Enterprise** = requires [jaseci-enterprise](https://github.com/jaseci-labs/jaseci-enterprise) with a valid license key.

## Roadmap

| Priority | Feature | Status |
|----------|---------|--------|
| P0 | Dashboard, Workbench, Graph Explorer | Done |
| P0 | Packages (jacpacks browser + install) | Done |
| P0 | Server Logs, Example App, AI Gateway | Done |
| P1 | Walker traversal capture & path overlay | Planned |
| P1 | Spawn walker on specific node | Planned |
| P2 | Visual Agent Builder (n8n-style flow) | Planned |
| P2 | Eval Runner dashboard | Planned |
| P3 | Deployment Manager (Helm, GitHub Actions) | Planned |
| P4 | Enterprise ops UI (orgs, users, audit) | Planned |

## Quick Start

```bash
pip install jaseci
cd your-jac-project
jac start main.jac
# -> http://localhost:8000/
```

Studio ships as part of any Jac application. All Studio pages are available alongside your app's routes.

## Development

```bash
git clone https://github.com/jaseci-labs/jaseci-studio
cd jaseci-studio
jac build
jac start main.jac --port 8001
```

## Project Structure

```
jaseci-studio/
├── jac.toml                 # jac-client project config
├── main.jac                 # Entry point: includes models + walkers, defines cl { app() }
├── models.jac               # Jac: graph nodes (StudioRoot, WalkerRun, Task, Project, etc.)
├── walkers.jac              # Jac: all backend walkers (:pub endpoints)
├── _log_handler.py          # Python: log capture for server logs page
├── pages/                   # jac-client file-based routing (frontend)
│   ├── layout.jac           # Root layout with sidebar navigation
│   ├── index.jac            # Dashboard (/)
│   ├── workbench.jac        # Walker testing (/workbench)
│   ├── graph.jac            # Graph explorer (/graph)
│   ├── packages.jac         # Jacpack browser (/packages)
│   ├── logs.jac             # Server logs (/logs)
│   ├── gateway.jac          # AI gateway (/gateway)
│   └── sandbox.jac          # JacBuilder redirect (/sandbox)
├── styles/
│   └── studio.css           # Dark-theme CSS
└── tests/
```

## Walker Endpoints

All walkers are `:pub` and become HTTP endpoints via `jac start`:

| Walker | Description |
|--------|-------------|
| `init_studio` | Bootstrap Studio subgraph |
| `get_dashboard` | Aggregated stats |
| `get_health` | Runtime health info |
| `list_walkers` | Available walker types (filters out Studio internals) |
| `run_walker_test` | Execute a walker with graph diff |
| `get_run_history` | Run history (filters out Studio internals) |
| `inspect_graph` | Graph structure for visualization (filters out Studio nodes) |
| `update_node_props` | Edit node properties inline |
| `get_server_logs` | Captured server log entries |
| `list_packages` / `install_package` | Browse & install jacpacks |
| `load_example_app` | Seed example Todo tasks |
| `list_tasks` / `add_task` / `toggle_task` / `delete_task` | Example app walkers |
| `add_model` / `list_models` / `remove_model` | AI model CRUD |
| `record_cost` / `get_cost_summary` | LLM cost tracking |
| `get_model_info` / `test_model_prompt` | AI gateway helpers |

## License

MIT License. See [LICENSE](LICENSE) for details.
