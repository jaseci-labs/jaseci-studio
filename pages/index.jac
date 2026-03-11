cl {
    sv import from ..main { get_dashboard, get_health, get_run_history }

    def:pub page -> JsxElement {
        has stats: dict = {},
            health: dict = {},
            recent_runs: list = [],
            loading: bool = true;

        async can with entry {
            try {
                dash_result = root spawn get_dashboard();
                if dash_result.reports and len(dash_result.reports) > 0 {
                    stats = dash_result.reports[0];
                }
            } except Exception as e {
                print("Dashboard error:", e);
            }

            try {
                health_result = root spawn get_health();
                if health_result.reports and len(health_result.reports) > 0 {
                    health = health_result.reports[0];
                }
            } except Exception as e {
                print("Health error:", e);
            }

            try {
                runs_result = root spawn get_run_history(limit=5);
                if runs_result.reports and len(runs_result.reports) > 0 {
                    recent_runs = runs_result.reports[0];
                }
            } except Exception as e {
                print("Runs error:", e);
            }

            loading = false;
        }

        if loading {
            return <div className="page-loading">Loading dashboard...</div>;
        }

        return
            <div className="page">
                <div className="page-header">
                    <h1>Dashboard</h1>
                    <p className="subtitle">Overview of your Jac application</p>
                </div>

                <div className="stats-grid">
                    <div className="stat-card">
                        <div className="stat-value accent">{stats.get("total_runs", 0)}</div>
                        <div className="stat-label">Total Runs</div>
                    </div>
                    <div className="stat-card">
                        <div className="stat-value success">{stats.get("success_runs", 0)}</div>
                        <div className="stat-label">Successful</div>
                    </div>
                    <div className="stat-card">
                        <div className="stat-value error">{stats.get("error_runs", 0)}</div>
                        <div className="stat-label">Errors</div>
                    </div>
                    <div className="stat-card">
                        <div className="stat-value accent">{stats.get("model_count", 0)}</div>
                        <div className="stat-label">AI Models</div>
                    </div>
                </div>

                <div className="row">
                    <div className="col">
                        <div className="card">
                            <div className="card-title">Recent Runs</div>
                            {len(recent_runs) == 0
                            and <div className="empty">No runs yet. Use the Workbench to test walkers.</div>
                            or <table>
                                <thead><tr><th>Walker</th><th>Status</th><th>Time</th></tr></thead>
                                <tbody>
                                    {[
                                        <tr key={r.get("walker_name", "") + r.get("status", "")}>
                                            <td className="mono">{r.get("walker_name", "")}</td>
                                            <td><span className={"badge badge-" + r.get("status", "")}>{r.get("status", "")}</span></td>
                                            <td>{r.get("duration_ms", 0)}ms</td>
                                        </tr>
                                        for r in recent_runs
                                    ]}
                                </tbody>
                            </table>}
                        </div>
                    </div>
                    <div className="col">
                        <div className="card">
                            <div className="card-title">System Health</div>
                            <p>Status: <span className="badge badge-success">{health.get("status", "unknown")}</span></p>
                            <p className="text-dim" style={{"marginTop": "8px", "fontSize": "12px"}}>
                                Uptime: {health.get("uptime_seconds", 0)}s
                            </p>
                        </div>
                    </div>
                </div>
            </div>;
    }
}
