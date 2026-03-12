"""Studio walkers — all backend endpoints for the developer workbench."""

include models;

import json;
import time;
import uuid as _uuid;

glob _STUDIO_TYPES: list = [
    "StudioRoot", "WalkerRun", "ModelConfig",
    "CostRecord", "Schedule", "SandboxSession"
];
glob _STUDIO_WALKERS: list = [
    "init_studio", "get_dashboard", "get_health",
    "list_walkers", "run_walker_test", "get_run_history",
    "inspect_graph", "add_model", "list_models", "remove_model",
    "record_cost", "get_cost_summary",
    "run_sandbox", "get_sandbox_history",
    "create_schedule", "list_schedules", "toggle_schedule", "delete_schedule",
    "update_node_props", "get_model_info", "test_model_prompt",
    "get_server_logs", "load_example_app",
    "list_packages", "get_package_detail", "install_package"
];
glob _LOG_RECORDS: list = [];

# ---------------------------------------------------------------------------
# Bootstrap
# ---------------------------------------------------------------------------

walker:pub init_studio {
    """Bootstrap the Studio subgraph with seed data."""

    can setup with Root entry {
        import from datetime { datetime }

        # Install log handler (idempotent)
        import sys;
        import os;
        _dir = os.path.dirname(os.path.abspath(__file__));
        if _dir not in sys.path {
            sys.path.insert(0, _dir);
        }
        import _log_handler;
        _log_handler.install_studio_log_handler(_LOG_RECORDS);

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

        for run_node in [studio -->](?:WalkerRun) {
            # Skip runs of studio infrastructure walkers
            if run_node.walker_name in _STUDIO_WALKERS { continue; }
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
        report {
            "total_runs": total_runs,
            "success_runs": success_runs,
            "error_runs": error_runs,
            "total_cost_usd": total_cost,
            "model_count": model_count
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
    """List all walker types available in the runtime via introspection."""

    can discover with Root entry {
        import from jaclang { JacRuntime as Jac }
        import from jaclang.jac0core.constructs { WalkerArchetype }

        walkers: list = [];

        # Use JacRuntime.list_walkers for discovery, then get_archetype for details
        for module_name in list(Jac.loaded_modules.keys()) + ["__main__"] {
            walker_names = Jac.list_walkers(module_name);
            for wname in walker_names {
                if wname in _STUDIO_WALKERS { continue; }
                already = False;
                for existing in walkers {
                    if existing["name"] == wname {
                        already = True;
                        break;
                    }
                }
                if already { continue; }

                cls = Jac.get_archetype(module_name, wname);
                doc = "";
                params: list = [];

                if cls is not None {
                    doc = cls.__doc__ or "";
                    doc = doc.strip().split("\n")[0] if doc.strip() else "";
                    # Filter out auto-generated docstrings like "init_studio()"
                    if doc == wname + "()" { doc = ""; }

                    # Extract has-fields (walker parameters) from annotations
                    skip_fields = ["reports", "_jac_entry_funcs_", "_jac_exit_funcs_"];
                    annotations = getattr(cls, "__annotations__", {});
                    for (field_name, field_type) in annotations.items() {
                        if not field_name.startswith("_") and field_name not in skip_fields {
                            default_val = getattr(cls, field_name, None);
                            type_str = str(field_type);
                            # Clean up type display
                            if type_str.startswith("<class '") { type_str = type_str[8:-2]; }
                            params.append({
                                "name": field_name,
                                "type": type_str,
                                "default": str(default_val) if default_val is not None else None
                            });
                        }
                    }
                }

                walkers.append({
                    "name": wname,
                    "module": module_name,
                    "type": "walker",
                    "description": doc,
                    "params": params
                });
            }
        }

        # Fallback: also check WalkerArchetype subclasses for any missed walkers
        for cls in WalkerArchetype.__subclasses__() {
            wname = cls.__name__;
            if wname in _STUDIO_WALKERS { continue; }
            already = False;
            for existing in walkers {
                if existing["name"] == wname {
                    already = True;
                    break;
                }
            }
            if already { continue; }

            doc = cls.__doc__ or "";
            doc = doc.strip().split("\n")[0] if doc.strip() else "";
            if doc == wname + "()" { doc = ""; }
            params2: list = [];
            skip_fields2 = ["reports", "_jac_entry_funcs_", "_jac_exit_funcs_"];
            annotations = getattr(cls, "__annotations__", {});
            for (field_name, field_type) in annotations.items() {
                if not field_name.startswith("_") and field_name not in skip_fields2 {
                    default_val = getattr(cls, field_name, None);
                    type_str = str(field_type);
                    if type_str.startswith("<class '") { type_str = type_str[8:-2]; }
                    params2.append({
                        "name": field_name,
                        "type": type_str,
                        "default": str(default_val) if default_val is not None else None
                    });
                }
            }
            walkers.append({
                "name": wname,
                "module": getattr(cls, "__module__", ""),
                "type": "walker",
                "description": doc,
                "params": params2
            });
        }

        report walkers;
    }
}

walker:pub run_walker_test {
    """Execute a named walker by dynamically spawning it on root."""

    has walker_name: str,
        payload: dict = {},
        target_node_id: str = "";

    can execute with Root entry {
        import from datetime { datetime }
        import from jaclang { JacRuntime as Jac }
        import from jaclang.runtimelib.context { CallState }

        existing = [here -->](?:StudioRoot);
        studio = existing[0] if len(existing) > 0 else (here ++> StudioRoot(initialized=True, created_at=datetime.utcnow().isoformat()))[0];

        start_time = time.time();
        result_data: dict = {};
        status = "error";
        reports: list = [];
        pre_snap: dict = {};
        post_snap: dict = {};

        try {
            target_module = "__main__";
            for mod_name in list(Jac.loaded_modules.keys()) + ["__main__"] {
                if self.walker_name in Jac.list_walkers(mod_name) {
                    target_module = mod_name;
                    break;
                }
            }

            walker_cls = Jac.get_archetype(target_module, self.walker_name);
            if walker_cls is None {
                raise ValueError(f"Walker '{self.walker_name}' not found in module '{target_module}'");
            }

            ctx = Jac.get_context();
            inner_cs = CallState();
            inner_token = ctx.call_state.set(inner_cs);

            try {
                w = walker_cls(**(self.payload if self.payload else {}));

                # Resolve target node
                spawn_target = ctx.get_root();
                if self.target_node_id {
                    search_queue: list = [spawn_target];
                    search_seen: list = [];
                    for _i in range(10000) {
                        if len(search_queue) == 0 { break; }
                        candidate = search_queue.pop(0);
                        cid = str(id(candidate));
                        if cid in search_seen { continue; }
                        search_seen.append(cid);
                        if cid == self.target_node_id {
                            spawn_target = candidate;
                            break;
                        }
                        for child in [candidate -->] {
                            search_queue.append(child);
                        }
                    }
                }

                # Snapshot graph BEFORE spawn
                pre_q: list = [ctx.get_root()];
                pre_seen: list = [];
                for _si in range(10000) {
                    if len(pre_q) == 0 { break; }
                    sn = pre_q.pop(0);
                    snid = str(id(sn));
                    if snid in pre_seen { continue; }
                    pre_seen.append(snid);
                    sn_type = type(sn).__name__;
                    if sn_type not in _STUDIO_TYPES {
                        sprops: dict = {};
                        for sk in dir(sn) {
                            if not sk.startswith("_") and sk not in ["architype", "anchor"] {
                                sv = getattr(sn, sk, None);
                                if sv is not None and not callable(sv) {
                                    sprops[sk] = str(sv);
                                }
                            }
                        }
                        pre_snap[snid] = {"type": sn_type, "props": sprops};
                    }
                    for sch in [sn -->] { pre_q.append(sch); }
                }

                Jac.spawn(w, spawn_target);

                # Snapshot graph AFTER spawn
                post_q: list = [ctx.get_root()];
                post_seen: list = [];
                for _si2 in range(10000) {
                    if len(post_q) == 0 { break; }
                    sn2 = post_q.pop(0);
                    snid2 = str(id(sn2));
                    if snid2 in post_seen { continue; }
                    post_seen.append(snid2);
                    sn2_type = type(sn2).__name__;
                    if sn2_type not in _STUDIO_TYPES {
                        sprops2: dict = {};
                        for sk2 in dir(sn2) {
                            if not sk2.startswith("_") and sk2 not in ["architype", "anchor"] {
                                sv2 = getattr(sn2, sk2, None);
                                if sv2 is not None and not callable(sv2) {
                                    sprops2[sk2] = str(sv2);
                                }
                            }
                        }
                        post_snap[snid2] = {"type": sn2_type, "props": sprops2};
                    }
                    for sch2 in [sn2 -->] { post_q.append(sch2); }
                }

                inner_cs.reports.put_nowait(inner_cs._sentinel);
                inner_reports: list = [];
                while not inner_cs.reports.empty() {
                    item = inner_cs.reports.get_nowait();
                    if item is not inner_cs._sentinel {
                        inner_reports.append(item);
                    }
                }
                reports = inner_reports;
            } finally {
                ctx.call_state.reset(inner_token);
            }

            result_data = {"reports": reports};
            status = "success";
        } except Exception as e {
            result_data = {"error": str(e)};
        }

        # Compute graph diff
        new_nodes: list = [];
        modified_nodes: list = [];
        for nid_key in post_snap {
            if nid_key not in pre_snap {
                new_nodes.append({
                    "id": nid_key,
                    "type": post_snap[nid_key]["type"],
                    "props": post_snap[nid_key]["props"]
                });
            } else {
                if post_snap[nid_key]["props"] != pre_snap[nid_key]["props"] {
                    modified_nodes.append({
                        "id": nid_key,
                        "type": post_snap[nid_key]["type"],
                        "before": pre_snap[nid_key]["props"],
                        "after": post_snap[nid_key]["props"]
                    });
                }
            }
        }
        graph_diff: dict = {
            "nodes_before": len(pre_snap),
            "nodes_after": len(post_snap),
            "created": new_nodes,
            "modified": modified_nodes
        };

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
            "result": result_data,
            "reports": reports,
            "graph_diff": graph_diff
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
            # Skip runs of studio infrastructure walkers
            if run_node.walker_name in _STUDIO_WALKERS { continue; }
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
    """Traverse the developer's application graph (skips Studio internals)."""

    has max_depth: int = 10;

    can start with Root entry {
        nodes: list = [];
        edges_list: list = [];
        seen: list = [];

        queue: list = [{"node": here, "parent": "", "depth": 0}];
        for _i in range(10000) {
            if len(queue) == 0 { break; }
            item: dict = queue[0];
            queue = queue[1:];
            nd = item["node"];
            node_id = str(id(nd));
            if node_id in seen { continue; }
            seen.append(node_id);

            node_type: str = type(nd).__name__;
            is_studio: bool = node_type in _STUDIO_TYPES;

            if not is_studio {
                props: dict = {};
                for k in dir(nd) {
                    if not k.startswith("_") and k not in ["architype", "anchor"] {
                        val = getattr(nd, k, None);
                        if val is not None and not callable(val) {
                            props[k] = str(val);
                        }
                    }
                }
                nodes.append({"id": node_id, "type": node_type, "props": props});
                if item["parent"] {
                    edges_list.append({"from": item["parent"], "to": node_id, "type": node_type});
                }
            }

            next_parent: str = node_id if not is_studio else item["parent"];
            if item["depth"] < self.max_depth {
                for child in [nd -->] {
                    queue.append({"node": child, "parent": next_parent, "depth": item["depth"] + 1});
                }
            }
        }

        report {"nodes": nodes, "edges": edges_list};
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
            "total_cost_usd": int(total_cost * 10000) / 10000.0,
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
            # Unescape literal \n and \t that may arrive from the client
            # (template strings in cl{} may double-escape newlines)
            code_text = self.code;
            # Check if newlines are escaped as literal backslash-n
            if "\n" not in code_text and len(code_text) > 20 {
                # No real newlines — likely escaped; decode unicode escapes
                import codecs;
                code_text = codecs.decode(code_text, "unicode_escape");
            }
            with tempfile.NamedTemporaryFile(
                mode="w", suffix=".jac", delete=False
            ) as f {
                f.write(code_text);
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

walker:pub update_node_props {
    """Update properties on a specific node found by BFS from root."""

    has node_id: str,
        updates: dict = {};

    can execute with Root entry {
        import from jaclang { JacRuntime as Jac }

        ctx = Jac.get_context();
        target = None;
        search_q: list = [ctx.get_root()];
        search_s: list = [];
        for _i in range(10000) {
            if len(search_q) == 0 { break; }
            candidate = search_q.pop(0);
            cid = str(id(candidate));
            if cid in search_s { continue; }
            search_s.append(cid);
            if cid == self.node_id {
                target = candidate;
                break;
            }
            for child in [candidate -->] {
                search_q.append(child);
            }
        }

        if target is None {
            report {"error": f"Node '{self.node_id}' not found"};
            disengage;
        }

        changed: list = [];
        for (prop_name, prop_val) in self.updates.items() {
            if hasattr(target, prop_name) {
                old_val = getattr(target, prop_name);
                if type(old_val).__name__ == "int" {
                    prop_val = int(prop_val);
                } elif type(old_val).__name__ == "float" {
                    prop_val = float(prop_val);
                } elif type(old_val).__name__ == "bool" {
                    prop_val = str(prop_val).lower() in ["true", "1", "yes"];
                }
                setattr(target, prop_name, prop_val);
                changed.append(prop_name);
            }
        }

        report {"node_id": self.node_id, "type": type(target).__name__, "changed": changed};
    }
}

walker:pub get_model_info {
    """Detect AI model configuration from environment variables."""

    can detect with Root entry {
        import os;

        env_keys: list = [
            "MTLLM_MODEL", "OPENAI_API_KEY", "ANTHROPIC_API_KEY",
            "GOOGLE_API_KEY", "OLLAMA_HOST", "OLLAMA_MODEL",
            "MTLLM_TEMPERATURE", "MTLLM_MAX_TOKENS"
        ];

        detected: list = [];
        for ek in env_keys {
            val = os.environ.get(ek, "");
            if val {
                display_val = val;
                if "KEY" in ek or "SECRET" in ek {
                    if len(val) > 4 {
                        display_val = "****" + val[-4:];
                    } else {
                        display_val = "****";
                    }
                }
                detected.append({"name": ek, "value": display_val, "is_set": True});
            } else {
                detected.append({"name": ek, "value": "", "is_set": False});
            }
        }

        active_model = os.environ.get("MTLLM_MODEL", "");
        provider = "unknown";
        if "gpt" in active_model or "o1" in active_model or "o3" in active_model {
            provider = "openai";
        } elif "claude" in active_model {
            provider = "anthropic";
        } elif "gemini" in active_model {
            provider = "google";
        } elif os.environ.get("OLLAMA_HOST", "") {
            provider = "ollama";
        }

        report {"active_model": active_model or "(not set)", "provider": provider, "env_vars": detected};
    }
}

walker:pub test_model_prompt {
    """Send a test prompt to the configured LLM via MTLLM."""

    has prompt: str = "Say hello in one sentence.";

    can test with Root entry {
        output_text = "";
        status = "error";

        try {
            import from mtllm.llms { Anthropic, OpenAI }
            import os;

            model_name = os.environ.get("MTLLM_MODEL", "");
            if not model_name {
                report {"status": "error", "output": "MTLLM_MODEL env var is not set."};
                disengage;
            }

            if "claude" in model_name {
                llm = Anthropic(model_name=model_name);
            } else {
                llm = OpenAI(model_name=model_name);
            }

            response = llm(meaning_in=self.prompt, output_hint="a short text response");
            output_text = str(response);
            status = "success";
        } except Exception as e {
            output_text = str(e);
        }

        report {"status": status, "output": output_text, "prompt": self.prompt};
    }
}

walker:pub get_server_logs {
    """Return recent server log entries."""

    has limit: int = 100,
        level: str = "";

    can collect with Root entry {
        entries: list = list(_LOG_RECORDS);
        entries.reverse();

        if self.level {
            lvl_upper = self.level.upper();
            entries = [e for e in entries if e["level"] == lvl_upper];
        }

        report entries[:self.limit];
    }
}

walker:pub load_example_app {
    """Load a sample Todo app into the graph."""

    can bootstrap with Root entry {
        # Check if already loaded by looking for Project nodes
        has_project = False;
        for n in [here -->] {
            if type(n).__name__ == "Project" {
                has_project = True;
                break;
            }
        }
        if has_project {
            report {"status": "already_loaded", "message": "Example app is already loaded."};
            disengage;
        }

        # Create hierarchy: Root -> Project -> Tasks
        project_node = Project(name="My First Project", description="A sample project to explore Jaseci Studio");
        here ++> project_node;
        t1 = Task(title="Learn Jac basics", done=True, priority="high");
        t2 = Task(title="Build a walker", done=True, priority="high");
        t3 = Task(title="Explore the graph", done=False, priority="medium");
        t4 = Task(title="Test AI integration", done=False, priority="low");
        t5 = Task(title="Deploy to production", done=False, priority="medium");
        project_node ++> t1;
        project_node ++> t2;
        project_node ++> t3;
        project_node ++> t4;
        project_node ++> t5;

        report {
            "status": "loaded",
            "message": "Example Todo app loaded! You now have 5 tasks and a project in your graph."
        };
    }
}

walker:pub list_tasks {
    """List all tasks with their status."""

    can list_all with Root entry {
        tasks: list = [];
        # Find Project node, then list tasks under it
        for p in [here -->] {
            if type(p).__name__ == "Project" {
                for t in [p -->] {
                    if type(t).__name__ == "Task" {
                        tasks.append({"title": t.title, "done": t.done, "priority": t.priority});
                    }
                }
            }
        }
        report tasks;
    }
}

walker:pub add_task {
    """Add a new task to the first project."""

    has title: str,
        priority: str = "medium";

    can create with Root entry {
        # Find Project node, add task under it
        for p in [here -->] {
            if type(p).__name__ == "Project" {
                new_task = Task(title=self.title, priority=self.priority);
                p ++> new_task;
                report {"created": self.title, "priority": self.priority};
                disengage;
            }
        }
        # No project found — create one first
        proj = Project(name="Default Project", description="Auto-created project");
        here ++> proj;
        new_task = Task(title=self.title, priority=self.priority);
        proj ++> new_task;
        report {"created": self.title, "priority": self.priority};
    }
}

walker:pub toggle_task {
    """Toggle a task's done status."""

    has task_title: str;

    can toggle with Root entry {
        for p in [here -->] {
            if type(p).__name__ == "Project" {
                for t in [p -->] {
                    if type(t).__name__ == "Task" and t.title == self.task_title {
                        t.done = not t.done;
                        report {"toggled": t.title, "done": t.done};
                        disengage;
                    }
                }
            }
        }
        report {"error": "Task not found: " + self.task_title};
    }
}

walker:pub delete_task {
    """Delete a task by title."""

    has task_title: str;

    can remove with Root entry {
        for p in [here -->] {
            if type(p).__name__ == "Project" {
                for t in [p -->] {
                    if type(t).__name__ == "Task" and t.title == self.task_title {
                        del t;
                        report {"deleted": self.task_title};
                        disengage;
                    }
                }
            }
        }
        report {"error": "Task not found: " + self.task_title};
    }
}

# ---------------------------------------------------------------------------
# Jacpack Registry — official template packs
# ---------------------------------------------------------------------------

glob _JACPACK_REGISTRY: list = [
    {
        "name": "multi-user-todo-app",
        "title": "Multi-User Todo App",
        "description": "Full-stack CRUD app with user authentication, priority levels, and hierarchical sub-todos. Great starting point for learning Jac.",
        "category": "Starter",
        "tags": ["fullstack", "auth", "crud"],
        "pack_url": "https://raw.githubusercontent.com/jaseci-labs/jacpacks/refs/heads/main/multi-user-todo-app/multi-user-todo-app.jacpack",
        "repo_path": "multi-user-todo-app",
        "difficulty": "beginner"
    },
    {
        "name": "multi-user-todo-meals-app",
        "title": "Todo App with AI Meal Planner",
        "description": "Todo app extended with Claude-powered meal planning, shopping lists, and nutritional indicators. Shows AI agent integration patterns.",
        "category": "AI",
        "tags": ["fullstack", "ai", "claude", "agents"],
        "pack_url": "https://raw.githubusercontent.com/jaseci-labs/jacpacks/refs/heads/main/multi-user-todo-meals-app/multi-user-todo-meals-app.jacpack",
        "repo_path": "multi-user-todo-meals-app",
        "difficulty": "intermediate"
    },
    {
        "name": "Algo",
        "title": "Algo — Voice AI Assistant",
        "description": "Voice-enabled personal AI assistant with calendar, email, and GitHub integration. Demonstrates multi-tool agent orchestration.",
        "category": "AI",
        "tags": ["voice", "ai", "agents", "integrations"],
        "pack_url": "https://raw.githubusercontent.com/jaseci-labs/jacpacks/refs/heads/main/Algo/Algo.jacpack",
        "repo_path": "Algo",
        "difficulty": "advanced"
    },
    {
        "name": "AI_Study_Helper",
        "title": "AI Study Helper",
        "description": "Intelligent study companion that transforms text into structured educational material using specialized AI agents.",
        "category": "AI",
        "tags": ["education", "ai", "agents"],
        "pack_url": "https://raw.githubusercontent.com/jaseci-labs/jacpacks/refs/heads/main/AI_Study_Helper/AI_Study_Helper.jacpack",
        "repo_path": "AI_Study_Helper",
        "difficulty": "intermediate"
    },
    {
        "name": "jac-playground",
        "title": "Jac Playground",
        "description": "Browser-based interactive code editor running entirely client-side via WebAssembly. Edit and run Jac code in the browser.",
        "category": "Developer Tools",
        "tags": ["wasm", "editor", "playground"],
        "pack_url": "https://raw.githubusercontent.com/jaseci-labs/jacpacks/refs/heads/main/jac-playground/jacPlayground.jacpack",
        "repo_path": "jac-playground",
        "difficulty": "intermediate"
    },
    {
        "name": "jac-gpt",
        "title": "Jac GPT",
        "description": "Documentation assistant for the Jac language. A fullstack app with MongoDB persistence that answers Jac programming questions.",
        "category": "AI",
        "tags": ["ai", "docs", "mongodb", "fullstack"],
        "pack_url": "https://raw.githubusercontent.com/jaseci-labs/jacpacks/refs/heads/main/jac-gpt/jac-gpt.jacpack",
        "repo_path": "jac-gpt",
        "difficulty": "intermediate"
    }
];

walker:pub list_packages {
    """List available jacpack templates from the registry."""

    has category: str = "",
        search: str = "";

    can list_all with Root entry {
        packs: list = [];
        for p in _JACPACK_REGISTRY {
            if self.category and p["category"] != self.category {
                continue;
            }
            if self.search {
                query = self.search.lower();
                name_match = query in p["name"].lower();
                title_match = query in p["title"].lower();
                desc_match = query in p["description"].lower();
                if not name_match and not title_match and not desc_match {
                    continue;
                }
            }
            packs.append(p);
        }
        report packs;
    }
}

walker:pub get_package_detail {
    """Get detailed info about a specific jacpack."""

    has name: str;

    can get_detail with Root entry {
        for p in _JACPACK_REGISTRY {
            if p["name"] == self.name {
                report p;
                disengage;
            }
        }
        report {"error": "Package not found: " + self.name};
    }
}

walker:pub install_package {
    """Install a jacpack template by running jac create server-side."""

    has name: str,
        project_name: str = "";

    can install with Root entry {
        import subprocess;
        import os;

        found = None;
        for p in _JACPACK_REGISTRY {
            if p["name"] == self.name {
                found = p;
            }
        }
        if not found {
            report {"status": "error", "message": "Package not found: " + self.name};
            disengage;
        }

        proj = self.project_name or self.name;
        pack_url = found["pack_url"];
        cwd = os.getcwd();
        target_dir = os.path.join(cwd, proj);

        # Check if already installed
        if os.path.exists(target_dir) {
            report {
                "status": "already_installed",
                "package": found["title"],
                "project_dir": target_dir,
                "message": "Project '" + proj + "' already exists at " + target_dir
            };
            disengage;
        }

        # Run jac create
        try {
            result = subprocess.run(
                ["jac", "create", proj, "--use", pack_url],
                cwd=cwd,
                capture_output=True,
                text=True,
                timeout=60
            );
            if result.returncode == 0 {
                report {
                    "status": "success",
                    "package": found["title"],
                    "project_dir": target_dir,
                    "message": "Installed '" + found["title"] + "' to " + target_dir,
                    "output": result.stdout
                };
            } else {
                report {
                    "status": "error",
                    "package": found["title"],
                    "message": "Install failed: " + (result.stderr or result.stdout),
                    "command": "jac create " + proj + " --use " + pack_url
                };
            }
        } except Exception as e {
            report {
                "status": "error",
                "package": found["title"],
                "message": "Install error: " + str(e),
                "command": "jac create " + proj + " --use " + pack_url
            };
        }
    }
}

# ---------------------------------------------------------------------------
# Module-level: record boot time
# ---------------------------------------------------------------------------
glob _BOOT_TIME: float = time.time();
