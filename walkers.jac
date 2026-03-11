"""Studio walkers — all backend endpoints for the developer workbench.

NOTE: This file is included from main.jac via `include walkers;`.
Node/edge types are available from `include models;` which runs first.
"""

import json;
import time;
import uuid as _uuid;

# ---------------------------------------------------------------------------
# Bootstrap
# ---------------------------------------------------------------------------

walker:pub init_studio {
    """Bootstrap the Studio subgraph with seed data."""

    can setup with Root entry {
        import from datetime { datetime }

        existing = [here -->](?:StudioRoot);
        studio = existing[0] if len(existing) > 0 else (here ++> StudioRoot(initialized=True, created_at=datetime.utcnow().isoformat()))[0];

        # Seed some sample data if fresh
        existing_models = [studio -->](?:ModelConfig);
        if len(existing_models) == 0 {
            # Sample models
            studio ++> ModelConfig(
                name="gpt-4o",
                model_id="gpt-4o",
                provider="openai",
                is_default=True,
                max_tokens=4096,
                temperature=0.7
            );
            studio ++> ModelConfig(
                name="claude-sonnet",
                model_id="claude-sonnet-4-20250514",
                provider="anthropic",
                max_tokens=8192,
                temperature=0.5
            );

            # Sample schedule
            studio ++> Schedule(
                id=str(_uuid.uuid4())[:8],
                walker_name="get_health",
                cron_expr="*/10 * * * *",
                enabled=True
            );

            # Sample run history
            now_str = datetime.utcnow().isoformat();
            studio ++> WalkerRun(
                walker_name="init_studio",
                status="success",
                result={"status": "initialized"},
                started_at=now_str,
                finished_at=now_str,
                duration_ms=12
            );
            studio ++> WalkerRun(
                walker_name="get_dashboard",
                status="success",
                result={"total_runs": 0},
                started_at=now_str,
                finished_at=now_str,
                duration_ms=3
            );
            studio ++> WalkerRun(
                walker_name="list_walkers",
                status="success",
                result={"count": 18},
                started_at=now_str,
                finished_at=now_str,
                duration_ms=1
            );

            report {"status": "initialized", "seeded": True};
        } else {
            report {"status": "already_initialized"};
        }
    }
}

# ---------------------------------------------------------------------------
# Dashboard
# ---------------------------------------------------------------------------

walker:pub get_dashboard {
    """Aggregate Studio stats for the dashboard view."""

    can gather with Root entry {
        import from datetime { datetime }

        existing = [here -->](?:StudioRoot);
        studio = existing[0] if len(existing) > 0 else (here ++> StudioRoot(initialized=True, created_at=datetime.utcnow().isoformat()))[0];

        total_runs = 0;
        success_runs = 0;
        error_runs = 0;
        total_cost = 0.0;
        model_count = 0;
        schedule_count = 0;

        for run_node in [studio -->](?:WalkerRun) {
            total_runs += 1;
            if run_node.status == "success" {
                success_runs += 1;
            }
            if run_node.status == "error" {
                error_runs += 1;
            }
        }
        for m in [studio -->](?:ModelConfig) {
            model_count += 1;
        }
        for c in [studio -->](?:CostRecord) {
            total_cost += c.cost_usd;
        }
        for s in [studio -->](?:Schedule) {
            schedule_count += 1;
        }
        report {
            "total_runs": total_runs,
            "success_runs": success_runs,
            "error_runs": error_runs,
            "total_cost_usd": total_cost,
            "model_count": model_count,
            "schedule_count": schedule_count
        };
    }
}

walker:pub get_health {
    """Return runtime health information."""

    can check with Root entry {
        import sys;
        import os;
        report {
            "status": "healthy",
            "python_version": sys.version.split(" ")[0],
            "pid": os.getpid(),
            "uptime_seconds": int(time.time() - _BOOT_TIME),
            "timestamp": time.time()
        };
    }
}

# ---------------------------------------------------------------------------
# Workbench — walker testing
# ---------------------------------------------------------------------------

walker:pub list_walkers {
    """List all walker types available in the runtime."""

    can discover with Root entry {
        # Return the known Studio walkers with descriptions
        walkers = [
            {"name": "init_studio", "type": "walker", "description": "Bootstrap Studio graph with seed data"},
            {"name": "get_dashboard", "type": "walker", "description": "Aggregate stats for dashboard"},
            {"name": "get_health", "type": "walker", "description": "Runtime health information"},
            {"name": "list_walkers", "type": "walker", "description": "List available walkers"},
            {"name": "run_walker_test", "type": "walker", "description": "Execute a walker and record result"},
            {"name": "get_run_history", "type": "walker", "description": "Recent walker run history"},
            {"name": "inspect_graph", "type": "walker", "description": "Graph structure for visualization"},
            {"name": "add_model", "type": "walker", "description": "Add an AI model configuration"},
            {"name": "list_models", "type": "walker", "description": "List configured AI models"},
            {"name": "remove_model", "type": "walker", "description": "Remove an AI model"},
            {"name": "record_cost", "type": "walker", "description": "Record LLM usage cost"},
            {"name": "get_cost_summary", "type": "walker", "description": "Aggregate cost data"},
            {"name": "create_schedule", "type": "walker", "description": "Create a cron schedule"},
            {"name": "list_schedules", "type": "walker", "description": "List all schedules"},
            {"name": "toggle_schedule", "type": "walker", "description": "Enable or disable a schedule"},
            {"name": "delete_schedule", "type": "walker", "description": "Delete a schedule"},
            {"name": "run_sandbox", "type": "walker", "description": "Execute Jac code in sandbox"},
            {"name": "get_sandbox_history", "type": "walker", "description": "Sandbox execution history"}
        ];
        report walkers;
    }
}

walker:pub run_walker_test {
    """Execute a named walker and record the result."""

    has walker_name: str,
        payload: dict = {};

    can execute with Root entry {
        import from datetime { datetime }

        existing = [here -->](?:StudioRoot);
        studio = existing[0] if len(existing) > 0 else (here ++> StudioRoot(initialized=True, created_at=datetime.utcnow().isoformat()))[0];

        start_time = time.time();
        result_data: dict = {};
        status = "error";

        try {
            result_data = {"info": f"Walker '{self.walker_name}' invoked", "payload": self.payload};
            status = "success";
        } except Exception as e {
            result_data = {"error": str(e)};
        }

        elapsed = int((time.time() - start_time) * 1000);
        now_str = datetime.utcnow().isoformat();

        studio ++> WalkerRun(
            walker_name=self.walker_name,
            payload=self.payload,
            status=status,
            result=result_data,
            started_at=now_str,
            finished_at=now_str,
            duration_ms=elapsed
        );

        report {
            "walker_name": self.walker_name,
            "status": status,
            "duration_ms": elapsed,
            "result": result_data
        };
    }
}

walker:pub get_run_history {
    """Get recent walker run history."""

    has limit: int = 20;

    can collect with Root entry {
        import from datetime { datetime }

        existing = [here -->](?:StudioRoot);
        studio = existing[0] if len(existing) > 0 else (here ++> StudioRoot(initialized=True, created_at=datetime.utcnow().isoformat()))[0];

        runs: list = [];
        for run_node in [studio -->](?:WalkerRun) {
            runs.append({
                "walker_name": run_node.walker_name,
                "status": run_node.status,
                "duration_ms": run_node.duration_ms,
                "started_at": run_node.started_at,
                "executed_at": run_node.started_at,
                "result": run_node.result
            });
        }
        runs.sort(key=lambda x: any: x["started_at"], reverse=True);
        report runs[:self.limit];
    }
}

walker:pub inspect_graph {
    """Traverse the graph and return structure for visualization."""

    has max_depth: int = 5,
        nodes: list = [],
        edges_list: list = [],
        seen: list = [],
        current_depth: int = 0;

    can start with Root entry {
        node_id = str(id(here));
        self.seen.append(node_id);
        self.nodes.append({
            "id": node_id,
            "type": "Root",
            "props": {}
        });
        if self.current_depth < self.max_depth {
            self.current_depth += 1;
            visit [-->];
        }
    }

    can inspect with entry {
        node_id = str(id(here));
        parent_id = "";
        if len(self.seen) > 0 {
            parent_id = self.seen[-1];
        }
        if node_id not in self.seen {
            self.seen.append(node_id);
            props: dict = {};
            node_type = type(here).__name__;
            for (k, v) in vars(here).items() {
                if not k.startswith("_") {
                    try {
                        json.dumps(v);
                        props[k] = v;
                    } except Exception {
                        props[k] = str(v);
                    }
                }
            }
            self.nodes.append({
                "id": node_id,
                "type": node_type,
                "props": props
            });
            self.edges_list.append({
                "from": parent_id,
                "to": node_id,
                "type": node_type
            });
            if self.current_depth < self.max_depth {
                self.current_depth += 1;
                visit [-->];
            }
        }
    }

    can finish with Root exit {
        report {"nodes": self.nodes, "edges": self.edges_list};
    }
}

# ---------------------------------------------------------------------------
# AI Gateway — model config CRUD
# ---------------------------------------------------------------------------

walker:pub add_model {
    """Add an AI model configuration."""

    has name: str,
        model_id: str = "",
        provider: str = "",
        api_key: str = "",
        is_default: bool = False,
        max_tokens: int = 4096,
        temperature: float = 0.7;

    can create with Root entry {
        import from datetime { datetime }

        existing = [here -->](?:StudioRoot);
        studio = existing[0] if len(existing) > 0 else (here ++> StudioRoot(initialized=True, created_at=datetime.utcnow().isoformat()))[0];

        for existing_model in [studio -->](?:ModelConfig) {
            if existing_model.name == self.name {
                report {"error": f"Model '{self.name}' already exists"};
                disengage;
            }
        }
        mid = self.model_id if self.model_id else self.name;
        new_model = (studio ++> ModelConfig(
            name=self.name,
            model_id=mid,
            provider=self.provider,
            api_key_env=self.api_key,
            is_default=self.is_default,
            max_tokens=self.max_tokens,
            temperature=self.temperature
        ))[0];
        report {
            "name": new_model.name,
            "model_id": new_model.model_id,
            "provider": new_model.provider,
            "is_default": new_model.is_default
        };
    }
}

walker:pub list_models {
    """List all configured AI models."""

    can collect with Root entry {
        import from datetime { datetime }

        existing = [here -->](?:StudioRoot);
        studio = existing[0] if len(existing) > 0 else (here ++> StudioRoot(initialized=True, created_at=datetime.utcnow().isoformat()))[0];

        models: list = [];
        for m in [studio -->](?:ModelConfig) {
            models.append({
                "name": m.name,
                "model_id": m.model_id,
                "provider": m.provider,
                "is_default": m.is_default,
                "max_tokens": m.max_tokens,
                "temperature": m.temperature
            });
        }
        report models;
    }
}

walker:pub remove_model {
    """Remove an AI model configuration."""

    has name: str;

    can find with Root entry {
        import from datetime { datetime }

        existing = [here -->](?:StudioRoot);
        studio = existing[0] if len(existing) > 0 else (here ++> StudioRoot(initialized=True, created_at=datetime.utcnow().isoformat()))[0];

        for m in [studio -->](?:ModelConfig) {
            if m.name == self.name {
                del m;
                report {"deleted": self.name};
                disengage;
            }
        }
        report {"error": f"Model '{self.name}' not found"};
    }
}

walker:pub record_cost {
    """Record an LLM usage cost entry."""

    has model_id: str,
        input_tokens: int = 0,
        output_tokens: int = 0,
        cost_usd: float = 0.0;

    can record with Root entry {
        import from datetime { datetime }

        existing = [here -->](?:StudioRoot);
        studio = existing[0] if len(existing) > 0 else (here ++> StudioRoot(initialized=True, created_at=datetime.utcnow().isoformat()))[0];

        studio ++> CostRecord(
            model_id=self.model_id,
            input_tokens=self.input_tokens,
            output_tokens=self.output_tokens,
            cost_usd=self.cost_usd,
            timestamp=datetime.utcnow().isoformat()
        );
        report {"recorded": True, "model_id": self.model_id, "cost_usd": self.cost_usd};
    }
}

walker:pub get_cost_summary {
    """Aggregate cost data across all models."""

    can aggregate with Root entry {
        import from datetime { datetime }

        existing = [here -->](?:StudioRoot);
        studio = existing[0] if len(existing) > 0 else (here ++> StudioRoot(initialized=True, created_at=datetime.utcnow().isoformat()))[0];

        total_requests = 0;
        total_cost = 0.0;
        by_model: dict = {};

        for c in [studio -->](?:CostRecord) {
            total_requests += 1;
            total_cost += c.cost_usd;
            mid = c.model_id;
            if mid not in by_model {
                by_model[mid] = {"model_id": mid, "requests": 0, "cost_usd": 0.0};
            }
            by_model[mid]["requests"] += 1;
            by_model[mid]["cost_usd"] += c.cost_usd;
        }
        report {
            "total_requests": total_requests,
            "total_cost_usd": round(total_cost, 4),
            "by_model": list(by_model.values())
        };
    }
}

# ---------------------------------------------------------------------------
# Scheduler — cron / webhook CRUD
# ---------------------------------------------------------------------------

walker:pub create_schedule {
    """Create a new cron schedule."""

    has walker_name: str,
        cron_expr: str = "*/5 * * * *",
        payload: dict = {};

    can create with Root entry {
        import from datetime { datetime }

        existing = [here -->](?:StudioRoot);
        studio = existing[0] if len(existing) > 0 else (here ++> StudioRoot(initialized=True, created_at=datetime.utcnow().isoformat()))[0];

        schedule_id = str(_uuid.uuid4())[:8];
        sched = (studio ++> Schedule(
            id=schedule_id,
            walker_name=self.walker_name,
            payload=self.payload,
            cron_expr=self.cron_expr,
            enabled=True
        ))[0];
        report {
            "id": sched.id,
            "walker_name": sched.walker_name,
            "cron_expr": sched.cron_expr,
            "enabled": sched.enabled
        };
    }
}

walker:pub list_schedules {
    """List all configured schedules."""

    can collect with Root entry {
        import from datetime { datetime }

        existing = [here -->](?:StudioRoot);
        studio = existing[0] if len(existing) > 0 else (here ++> StudioRoot(initialized=True, created_at=datetime.utcnow().isoformat()))[0];

        schedules: list = [];
        for s in [studio -->](?:Schedule) {
            schedules.append({
                "id": s.id,
                "walker_name": s.walker_name,
                "cron_expr": s.cron_expr,
                "enabled": s.enabled,
                "last_run": s.last_run
            });
        }
        report schedules;
    }
}

walker:pub toggle_schedule {
    """Toggle a schedule on/off."""

    has schedule_id: str;

    can toggle with Root entry {
        import from datetime { datetime }

        existing = [here -->](?:StudioRoot);
        studio = existing[0] if len(existing) > 0 else (here ++> StudioRoot(initialized=True, created_at=datetime.utcnow().isoformat()))[0];

        for s in [studio -->](?:Schedule) {
            if s.id == self.schedule_id {
                s.enabled = not s.enabled;
                report {"id": s.id, "enabled": s.enabled};
                disengage;
            }
        }
        report {"error": f"Schedule '{self.schedule_id}' not found"};
    }
}

walker:pub delete_schedule {
    """Delete a schedule by ID."""

    has schedule_id: str;

    can remove with Root entry {
        import from datetime { datetime }

        existing = [here -->](?:StudioRoot);
        studio = existing[0] if len(existing) > 0 else (here ++> StudioRoot(initialized=True, created_at=datetime.utcnow().isoformat()))[0];

        for s in [studio -->](?:Schedule) {
            if s.id == self.schedule_id {
                del s;
                report {"deleted": self.schedule_id};
                disengage;
            }
        }
        report {"error": f"Schedule '{self.schedule_id}' not found"};
    }
}

# ---------------------------------------------------------------------------
# Sandbox — Jac code execution
# ---------------------------------------------------------------------------

walker:pub run_sandbox {
    """Execute Jac code in a sandbox and capture output."""

    has code: str,
        timeout_sec: int = 10;

    can execute with Root entry {
        import subprocess;
        import tempfile;
        import os;
        import from datetime { datetime }

        existing = [here -->](?:StudioRoot);
        studio = existing[0] if len(existing) > 0 else (here ++> StudioRoot(initialized=True, created_at=datetime.utcnow().isoformat()))[0];

        session_id = str(_uuid.uuid4())[:8];
        created = datetime.utcnow().isoformat();
        output_text = "";
        status = "error";

        try {
            with tempfile.NamedTemporaryFile(
                mode="w", suffix=".jac", delete=False
            ) as f {
                f.write(self.code);
                tmp_path = f.name;
            }
            try {
                proc = subprocess.run(
                    ["jac", "run", tmp_path],
                    capture_output=True,
                    text=True,
                    timeout=self.timeout_sec
                );
                output_text = proc.stdout;
                if proc.returncode != 0 {
                    output_text = proc.stdout + "\n" + proc.stderr;
                    status = "error";
                } else {
                    status = "success";
                }
            } except subprocess.TimeoutExpired {
                output_text = f"Execution timed out after {self.timeout_sec}s";
                status = "timeout";
            } finally {
                os.unlink(tmp_path);
            }
        } except Exception as e {
            output_text = str(e);
        }

        studio ++> SandboxSession(
            session_id=session_id,
            code=self.code,
            output=output_text,
            status=status,
            created_at=created
        );

        report {
            "session_id": session_id,
            "status": status,
            "output": output_text
        };
    }
}

walker:pub get_sandbox_history {
    """Get recent sandbox execution history."""

    has limit: int = 10;

    can collect with Root entry {
        import from datetime { datetime }

        existing = [here -->](?:StudioRoot);
        studio = existing[0] if len(existing) > 0 else (here ++> StudioRoot(initialized=True, created_at=datetime.utcnow().isoformat()))[0];

        sessions: list = [];
        for s in [studio -->](?:SandboxSession) {
            sessions.append({
                "session_id": s.session_id,
                "code": s.code,
                "output": s.output,
                "status": s.status,
                "executed_at": s.created_at
            });
        }
        sessions.sort(key=lambda x: any: x["executed_at"], reverse=True);
        report sessions[:self.limit];
    }
}

# ---------------------------------------------------------------------------
# Module-level: record boot time
# ---------------------------------------------------------------------------
glob _BOOT_TIME: float = time.time();
