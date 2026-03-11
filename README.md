# Jaseci Studio

Developer workbench for building, testing, and operating [Jac](https://github.com/jaseci-labs/jaseci) applications. Provides a visual graph explorer, AI gateway, eval dashboard, cron/webhook triggers, and sandbox execution — all accessible from a single UI at `/_studio`.

## Architecture

Jaseci Studio is the **product layer** built on top of the Jaseci ecosystem:

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
│  jaclang (OSS)                                  │
│  Compiler · Runtime · CLI                       │
└─────────────────────────────────────────────────┘
```

Core logic is written in **Jac** (graph models, walkers). Python is used only for the plugin entry point, FastAPI routing, and license gating.

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

# In your Jac app, mount Studio in plugin.py or directly:
from jaseci_studio.plugin import mount_studio
mount_studio(app)

# -> http://localhost:8000/_studio  (Studio UI)
```

## Development

```bash
git clone https://github.com/jaseci-labs/jaseci-studio
cd jaseci-studio
pip install -e ".[dev]"
python3.12 -m pytest tests/ -q
```

## Project Structure

```
src/jaseci_studio/
├── models.jac          # Jac: graph nodes (StudioRoot, WalkerRun, ModelConfig, etc.)
├── workbench.jac       # Jac: walker testing, graph inspection walkers
├── dashboard.jac       # Jac: metrics aggregation, health walkers
├── gateway.jac         # Jac: AI model config CRUD, cost tracking walkers
├── scheduler.jac       # Jac: cron/webhook schedule management walkers
├── sandbox.jac         # Jac: isolated code execution walkers
├── plugin.py           # Python: mount_studio() entry point
├── api/
│   └── routes.py       # Python: FastAPI router (thin layer over Jac walkers)
├── utils/
│   └── licensing.py    # Python: tier detection and feature gating
└── client/
    └── dist/           # Static: vanilla HTML/JS/CSS SPA
        ├── index.html
        ├── app.js
        └── style.css
```

## API Endpoints

All endpoints are prefixed with `/_studio/api`:

| Method | Path | Description |
|--------|------|-------------|
| GET | `/dashboard` | Aggregated stats |
| GET | `/health` | Runtime health |
| GET | `/walkers` | List registered walkers |
| POST | `/walkers/run` | Execute a walker |
| GET | `/walkers/history` | Run history |
| GET | `/graph` | Graph structure for visualization |
| GET/POST | `/models` | AI model config CRUD |
| DELETE | `/models/{model_id}` | Remove model |
| GET/POST | `/costs` | LLM cost tracking |
| GET/POST | `/schedules` | Schedule CRUD |
| PUT | `/schedules/toggle` | Enable/disable schedule |
| DELETE | `/schedules/{name}` | Remove schedule |
| POST | `/sandbox/run` | Execute Jac code |
| GET | `/sandbox/history` | Sandbox session history |
| GET | `/tier` | Current license tier |

## License

MIT License. See [LICENSE](LICENSE) for details.

Pro and Enterprise features require a [jaseci-enterprise](https://github.com/jaseci-labs/jaseci-enterprise) license key. The feature code is open source — the license gates runtime activation.
