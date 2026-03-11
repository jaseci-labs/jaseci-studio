"""Dashboard walkers — metrics and health aggregation."""

import time;

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

node ModelConfig {
    has model_id: str,
        provider: str = "",
        api_key_env: str = "",
        is_default: bool = False,
        max_tokens: int = 4096,
        temperature: float = 0.7;
}

node CostRecord {
    has model_id: str,
        input_tokens: int = 0,
        output_tokens: int = 0,
        cost_usd: float = 0.0,
        timestamp: str = "";
}

node Schedule {
    has name: str,
        walker_name: str = "",
        payload: dict = {},
        cron_expr: str = "",
        webhook_path: str = "",
        enabled: bool = True,
        last_run: str = "",
        next_run: str = "";
}

walker GetDashboard {
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
        for model_node in [-->](?:ModelConfig) {
            self.model_count += 1;
        }
        for cost_node in [-->](?:CostRecord) {
            self.total_cost += cost_node.cost_usd;
        }
        for sched_node in [-->](?:Schedule) {
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

walker GetHealth {
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
