"""Workbench walkers — test, inspect, and debug walkers and graphs."""

import json;
import time;

walker InitStudio {
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

walker ListWalkers {
    """List all walker types available in the runtime."""

    can discover with Root entry {
        walkers: list = [];
        report walkers;
    }
}

walker RunWalkerTest {
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

walker GetRunHistory {
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

walker InspectGraph {
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

node StudioRoot {
    has initialized: bool = False,
        created_at: str = "";
}

node WalkerRun {
    has walker_name: str,
        payload: dict = {},
        status: str = "pending",
        result: dict = {},
        started_at: str = "",
        finished_at: str = "",
        duration_ms: int = 0;
}
