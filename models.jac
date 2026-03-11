"""Studio graph models — nodes and edges for the developer workbench."""

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
    has name: str,
        model_id: str = "",
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
    has id: str,
        walker_name: str = "",
        payload: dict = {},
        cron_expr: str = "",
        webhook_path: str = "",
        enabled: bool = True,
        last_run: str = "",
        next_run: str = "";
}

node SandboxSession {
    has session_id: str,
        code: str = "",
        output: str = "",
        status: str = "idle",
        created_at: str = "";
}

edge HasRun {}
edge HasModel {}
edge HasCost {}
edge HasSchedule {}
edge HasSession {}
