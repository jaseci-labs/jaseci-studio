"""Dashboard page — overview of Studio stats and health."""

sv import from ...main { get_dashboard, get_health, get_run_history }

def:pub page() -> JsxElement {
    has stats: dict = {};
    has health: dict = {};
    has recent_runs: list = [];
    has loading: bool = True;

    async can with entry {
        try {
            dash_result = root spawn get_dashboard();
            if dash_result.reports and dash_result.reports.length > 0 {
                stats = dash_result.reports[0];
            }
        } except Exception as e {
            stats = {};
        }

        try {
            health_result = root spawn get_health();
            if health_result.reports and health_result.reports.length > 0 {
                health = health_result.reports[0];
            }
        } except Exception as e {
            health = {};
        }

        try {
            runs_result = root spawn get_run_history(limit=5);
            if runs_result.reports and runs_result.reports.length > 0 {
                recent_runs = runs_result.reports[0];
            }
        } except Exception as e {
            recent_runs = [];
        }

        loading = False;
    }

    if loading {
        return <div className="page-loading">Loading dashboard...</div>;
    }

    return <div className="page">
        <div className="page-header">
            <h1>Dashboard</h1>
            <p className="subtitle">Overview of your Jac application</p>
        </div>

        <div className="stats-grid">
            <div className="stat-card">
                <div className="stat-value accent">{stats["total_runs"] or 0}</div>
                <div className="stat-label">Total Runs</div>
            </div>
            <div className="stat-card">
                <div className="stat-value success">{stats["success_runs"] or 0}</div>
                <div className="stat-label">Successful</div>
            </div>
            <div className="stat-card">
                <div className="stat-value error">{stats["error_runs"] or 0}</div>
                <div className="stat-label">Errors</div>
            </div>
            <div className="stat-card">
                <div className="stat-value accent">{stats["model_count"] or 0}</div>
                <div className="stat-label">AI Models</div>
            </div>
            <div className="stat-card">
                <div className="stat-value">${(stats["total_cost_usd"] or 0).toFixed(4)}</div>
                <div className="stat-label">Total LLM Cost</div>
            </div>
            <div className="stat-card">
                <div className="stat-value">{stats["schedule_count"] or 0}</div>
                <div className="stat-label">Schedules</div>
            </div>
        </div>

        <div className="row">
            <div className="col">
                <div className="card">
                    <div className="card-title">Recent Runs</div>
                    {recent_runs.length == 0 and (
                        <div className="empty">No runs yet</div>
                    ) or (
                        <table>
                            <thead><tr><th>Walker</th><th>Status</th><th>Time</th></tr></thead>
                            <tbody>
                                {[
                                    <tr key={i}>
                                        <td>{r["walker_name"]}</td>
                                        <td><span className={"badge badge-" + r["status"]}>{r["status"]}</span></td>
                                        <td>{r["duration_ms"]}ms</td>
                                    </tr>
                                    for (i, r) in enumerate(recent_runs)
                                ]}
                            </tbody>
                        </table>
                    )}
                </div>
            </div>
            <div className="col">
                <div className="card">
                    <div className="card-title">System Health</div>
                    <p>Status: <span className="badge badge-success">{health["status"] or "unknown"}</span></p>
                    <p className="text-dim" style={{"marginTop": "8px", "fontSize": "12px"}}>
                        Python: {(health["python_version"] or "").split(" ")[0]}<br />
                        PID: {health["pid"] or "-"}
                    </p>
                </div>
            </div>
        </div>
    </div>;
}
