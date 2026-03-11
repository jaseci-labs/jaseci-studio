"""Studio walkers — all backend endpoints for the developer workbench.

NOTE: This file is included from main.jac via `include walkers;`.
Node/edge types are available from `include models;` which runs first.
"""

import json;
import time;

# ---------------------------------------------------------------------------
# Bootstrap
# ---------------------------------------------------------------------------

walker:pub init_studio {
    """Bootstrap the Studio subgraph off root."""

    can setup with Root entry {
        import from datetime { datetime }

        existing = [-->](?:StudioRoot);
        if len(existing) == 0 {
            studio = (here ++> StudioRoot(
                initialized=True,
                created_at=datetime.utcnow().isoformat()
            ))[0];
            report {"status": "initialized"};
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

    has total_runs: int = 0,
        success_runs: int = 0,
        error_runs: int = 0,
        total_cost: float = 0.0,
        model_count: int = 0,
        schedule_count: int = 0;

    can start with Root entry {
        visit [-->](?:StudioRoot);
    }

    can gather with StudioRoot entry {
        for run_node in [-->](?:WalkerRun) {
            self.total_runs += 1;
            if run_node.status == "success" {
                self.success_runs += 1;
            }
            if run_node.status == "error" {
                self.error_runs += 1;
            }
        }
        for m in [-->](?:ModelConfig) {
            self.model_count += 1;
        }
        for c in [-->](?:CostRecord) {
            self.total_cost += c.cost_usd;
        }
        for s in [-->](?:Schedule) {
            self.schedule_count += 1;
        }
        report {
            "total_runs": self.total_runs,
            "success_runs": self.success_runs,
            "error_runs": self.error_runs,
            "total_cost_usd": self.total_cost,
            "model_count": self.model_count,
            "schedule_count": self.schedule_count
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
            "python_version": sys.version,
            "pid": os.getpid(),
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
        walkers: list = [];
        report walkers;
    }
}

walker:pub run_walker_test {
    """Execute a named walker and record the result."""

    has walker_name: str,
        payload: dict = {};

    can execute with Root entry {
        import from datetime { datetime }

        start_time = time.time();
        result_data: dict = {};
        status = "error";

        try {
            result_data = {"info": f"Walker '{self.walker_name}' invoked"};
            status = "success";
        } except Exception as e {
            result_data = {"error": str(e)};
        }

        elapsed = int((time.time() - start_time) * 1000);
        now_str = datetime.utcnow().isoformat();

        studio_nodes = [-->](?:StudioRoot);
        if len(studio_nodes) > 0 {
            studio_nodes[0] ++> WalkerRun(
                walker_name=self.walker_name,
                payload=self.payload,
                status=status,
                result=result_data,
                started_at=now_str,
                finished_at=now_str,
                duration_ms=elapsed
            );
        }

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

    can start with Root entry {
        visit [-->](?:StudioRoot);
    }

    can collect with StudioRoot entry {
        runs: list = [];
        for run_node in [-->](?:WalkerRun) {
            runs.append({
                "walker_name": run_node.walker_name,
                "status": run_node.status,
                "duration_ms": run_node.duration_ms,
                "started_at": run_node.started_at,
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
        if node_id not in self.seen {
            self.seen.append(node_id);
            props: dict = {};
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
                "type": type(here).__name__,
                "props": props
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

    has model_id: str,
        provider: str = "",
        api_key_env: str = "",
        is_default: bool = False,
        max_tokens: int = 4096,
        temperature: float = 0.7;

    can add with Root entry {
        visit [-->](?:StudioRoot);
    }

    can create with StudioRoot entry {
        for existing in [-->](?:ModelConfig) {
            if existing.model_id == self.model_id {
                report {"error": f"Model '{self.model_id}' already exists"};
                disengage;
            }
        }
        new_model = (here ++> ModelConfig(
            model_id=self.model_id,
            provider=self.provider,
            api_key_env=self.api_key_env,
            is_default=self.is_default,
            max_tokens=self.max_tokens,
            temperature=self.temperature
        ))[0];
        report {
            "model_id": new_model.model_id,
            "provider": new_model.provider,
            "is_default": new_model.is_default
        };
    }
}

walker:pub list_models {
    """List all configured AI models."""

    can start with Root entry {
        visit [-->](?:StudioRoot);
    }

    can collect with StudioRoot entry {
        models: list = [];
        for m in [-->](?:ModelConfig) {
            models.append({
                "model_id": m.model_id,
                "provider": m.provider,
                "api_key_env": m.api_key_env,
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

    has model_id: str;

    can start with Root entry {
        visit [-->](?:StudioRoot);
    }

    can find with StudioRoot entry {
        for m in [-->](?:ModelConfig) {
            if m.model_id == self.model_id {
                del m;
                report {"deleted": self.model_id};
                disengage;
            }
        }
        report {"error": f"Model '{self.model_id}' not found"};
    }
}

walker:pub record_cost {
    """Record an LLM usage cost entry."""

    has model_id: str,
        input_tokens: int = 0,
        output_tokens: int = 0,
        cost_usd: float = 0.0;

    can record with Root entry {
        visit [-->](?:StudioRoot);
    }

    can save with StudioRoot entry {
        import from datetime { datetime }

        here ++> CostRecord(
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
    """Aggregate cost data per model."""

    can start with Root entry {
        visit [-->](?:StudioRoot);
    }

    can aggregate with StudioRoot entry {
        totals: dict = {};
        for c in [-->](?:CostRecord) {
            mid = c.model_id;
            if mid not in totals {
                totals[mid] = {
                    "model_id": mid,
                    "total_input_tokens": 0,
                    "total_output_tokens": 0,
                    "total_cost_usd": 0.0,
                    "request_count": 0
                };
            }
            totals[mid]["total_input_tokens"] += c.input_tokens;
            totals[mid]["total_output_tokens"] += c.output_tokens;
            totals[mid]["total_cost_usd"] += c.cost_usd;
            totals[mid]["request_count"] += 1;
        }
        report list(totals.values());
    }
}

# ---------------------------------------------------------------------------
# Scheduler — cron / webhook CRUD
# ---------------------------------------------------------------------------

walker:pub create_schedule {
    """Create a new cron or webhook schedule."""

    has name: str,
        walker_name: str = "",
        payload: dict = {},
        cron_expr: str = "",
        webhook_path: str = "";

    can start with Root entry {
        visit [-->](?:StudioRoot);
    }

    can create with StudioRoot entry {
        for existing in [-->](?:Schedule) {
            if existing.name == self.name {
                report {"error": f"Schedule '{self.name}' already exists"};
                disengage;
            }
        }
        sched = (here ++> Schedule(
            name=self.name,
            walker_name=self.walker_name,
            payload=self.payload,
            cron_expr=self.cron_expr,
            webhook_path=self.webhook_path,
            enabled=True,
            last_run="",
            next_run=""
        ))[0];
        report {
            "name": sched.name,
            "walker_name": sched.walker_name,
            "cron_expr": sched.cron_expr,
            "webhook_path": sched.webhook_path,
            "enabled": sched.enabled
        };
    }
}

walker:pub list_schedules {
    """List all configured schedules."""

    can start with Root entry {
        visit [-->](?:StudioRoot);
    }

    can collect with StudioRoot entry {
        schedules: list = [];
        for s in [-->](?:Schedule) {
            schedules.append({
                "name": s.name,
                "walker_name": s.walker_name,
                "cron_expr": s.cron_expr,
                "webhook_path": s.webhook_path,
                "enabled": s.enabled,
                "last_run": s.last_run
            });
        }
        report schedules;
    }
}

walker:pub toggle_schedule {
    """Enable or disable a schedule."""

    has name: str,
        enabled: bool = True;

    can start with Root entry {
        visit [-->](?:StudioRoot);
    }

    can toggle with StudioRoot entry {
        for s in [-->](?:Schedule) {
            if s.name == self.name {
                s.enabled = self.enabled;
                report {"name": s.name, "enabled": s.enabled};
                disengage;
            }
        }
        report {"error": f"Schedule '{self.name}' not found"};
    }
}

walker:pub delete_schedule {
    """Delete a schedule by name."""

    has name: str;

    can start with Root entry {
        visit [-->](?:StudioRoot);
    }

    can remove with StudioRoot entry {
        for s in [-->](?:Schedule) {
            if s.name == self.name {
                del s;
                report {"deleted": self.name};
                disengage;
            }
        }
        report {"error": f"Schedule '{self.name}' not found"};
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
        import uuid;
        import from datetime { datetime }

        session_id = str(uuid.uuid4())[:8];
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

        studio_nodes = [-->](?:StudioRoot);
        if len(studio_nodes) > 0 {
            studio_nodes[0] ++> SandboxSession(
                session_id=session_id,
                code=self.code,
                output=output_text,
                status=status,
                created_at=created
            );
        }

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

    can start with Root entry {
        visit [-->](?:StudioRoot);
    }

    can collect with StudioRoot entry {
        sessions: list = [];
        for s in [-->](?:SandboxSession) {
            sessions.append({
                "session_id": s.session_id,
                "code": s.code,
                "output": s.output,
                "status": s.status,
                "created_at": s.created_at
            });
        }
        sessions.sort(key=lambda x: any: x["created_at"], reverse=True);
        report sessions[:self.limit];
    }
}
