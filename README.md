# Jaseci Studio

Developer workbench for building, testing, and operating [Jac](https://github.com/jaseci-labs/jaseci) applications. Provides a visual graph explorer, AI gateway, eval dashboard, cron/webhook triggers, and sandbox execution — all accessible from a single UI.

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

# Start with a Jac app
cd your-project/
jac start main.jac --studio
# -> http://localhost:8000          (your app)
# -> http://localhost:8000/_studio  (Studio UI)
```

## Development

```bash
git clone https://github.com/jaseci-labs/jaseci-studio
cd jaseci-studio
pip install -e ".[dev]"
python -m pytest tests/ -q
```

## Project Structure

```
src/jaseci_studio/
├── api/            # FastAPI routers for Studio endpoints
├── gateway/        # AI Gateway (LiteLLM routing, cost tracking)
├── workbench/      # Walker testing, graph inspection
├── dashboard/      # Metrics, health, session monitoring
├── scheduler/      # Cron and webhook trigger management
├── sandbox/        # Isolated code execution (nsjail/bubblewrap)
└── utils/          # Licensing, shared helpers
```

## License

MIT License. See [LICENSE](LICENSE) for details.

Pro and Enterprise features require a [jaseci-enterprise](https://github.com/jaseci-labs/jaseci-enterprise) license key. The feature code is open source — the license gates runtime activation.
