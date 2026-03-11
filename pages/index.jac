cl import from "@jac/runtime" { Link }

cl {
    sv import from ..main { init_studio, get_dashboard, get_health, get_run_history }

    def:pub page -> JsxElement {
        has stats: dict = {},
            health: dict = {},
            recent_runs: list = [],
            loading: bool = true;

        async can with entry {
            # Auto-bootstrap on first load
            try {
                root spawn init_studio();
            } except Exception as e {
                print("Init error:", e);
            }

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
                runs_result = root spawn get_run_history(limit=8);
                if runs_result.reports and len(runs_result.reports) > 0 {
                    recent_runs = runs_result.reports[0];
                }
            } except Exception as e {
                print("Runs error:", e);
            }

            loading = false;
        }

        if loading {
            return
                <div className="page-loading">
                    <div className="spinner"></div>
                    <div className="loading-text">Loading dashboard...</div>
                </div>;
        }

        total = stats["total_runs"] or 0;
        successes = stats["success_runs"] or 0;
        errors = stats["error_runs"] or 0;
        models = stats["model_count"] or 0;
        schedules = stats["schedule_count"] or 0;
        h_status = health["status"] or "unknown";

        return
            <div className="page">
                <div className="page-header">
                    <div className="page-header-left">
                        <h1>Dashboard</h1>
                        <div className="subtitle">Overview of your Jac application runtime</div>
                    </div>
                    <div className="page-header-actions">
                        <span className={"badge " + ("badge-success" if h_status == "healthy" else "badge-warning")}>
                            <span className="badge-dot"></span>
                            {h_status}
                        </span>
                    </div>
                </div>

                <div className="stats-grid">
                    <div className="stat-card accent-stripe">
                        <div className="stat-icon">~</div>
                        <div className="stat-value accent">{total}</div>
                        <div className="stat-label">Total Runs</div>
                    </div>
                    <div className="stat-card success-stripe">
                        <div className="stat-icon">+</div>
                        <div className="stat-value success">{successes}</div>
                        <div className="stat-label">Successful</div>
                    </div>
                    <div className="stat-card error-stripe">
                        <div className="stat-icon">x</div>
                        <div className="stat-value error">{errors}</div>
                        <div className="stat-label">Errors</div>
                    </div>
                    <div className="stat-card info-stripe">
                        <div className="stat-icon">&lt;/&gt;</div>
                        <div className="stat-value info">{models}</div>
                        <div className="stat-label">AI Models</div>
                    </div>
                    <div className="stat-card warning-stripe">
                        <div className="stat-icon">:::</div>
                        <div className="stat-value warning">{schedules}</div>
                        <div className="stat-label">Schedules</div>
                    </div>
                </div>

                <div className="section-title">Quick Actions</div>
                <div className="quick-actions" style={{"marginBottom": "24px"}}>
                    <Link to="/workbench" className="quick-action">
                        <span className="qa-icon">&gt;_</span>
                        <div className="qa-text">
                            <div className="qa-title">Run a Walker</div>
                            <div className="qa-desc">Test and debug walkers interactively</div>
                        </div>
                    </Link>
                    <Link to="/graph" className="quick-action">
                        <span className="qa-icon">o-o</span>
                        <div className="qa-text">
                            <div className="qa-title">Explore Graph</div>
                            <div className="qa-desc">Browse nodes and edges visually</div>
                        </div>
                    </Link>
                    <Link to="/sandbox" className="quick-action">
                        <span className="qa-icon">[ ]</span>
                        <div className="qa-text">
                            <div className="qa-title">Open Sandbox</div>
                            <div className="qa-desc">Write and execute Jac code live</div>
                        </div>
                    </Link>
                </div>

                <div className="row">
                    <div className="col-2">
                        <div className="card">
                            <div className="card-header">
                                <div className="card-title">Recent Activity</div>
                                <Link to="/workbench" className="btn btn-ghost btn-sm">View all</Link>
                            </div>
                            {len(recent_runs) == 0
                            and <div className="empty-state">
                                <div className="empty-icon">&gt;_</div>
                                <div className="empty-title">No runs yet</div>
                                <div className="empty-desc">Head to the Workbench to test your first walker</div>
                            </div>
                            or <div>
                                {[
                                    <div key={r["walker_name"] + r["executed_at"]} className="history-item">
                                        <div className={"history-dot " + r["status"]}>
                                        </div>
                                        <div className="history-info">
                                            <div className="history-name">{r["walker_name"]}</div>
                                            <div className="history-meta">{r["duration_ms"]}ms</div>
                                        </div>
                                        <div className="history-time">
                                            <span className={"badge badge-" + r["status"]}>{r["status"]}</span>
                                        </div>
                                    </div>
                                    for r in recent_runs
                                ]}
                            </div>}
                        </div>
                    </div>

                    <div className="col">
                        <div className="card">
                            <div className="card-header">
                                <div className="card-title">System Info</div>
                            </div>
                            <div style={{"display": "flex", "flexDirection": "column", "gap": "12px"}}>
                                <div style={{"display": "flex", "justifyContent": "space-between", "fontSize": "13px"}}>
                                    <span className="text-secondary">Status</span>
                                    <span className={"badge " + ("badge-success" if h_status == "healthy" else "badge-warning")}>
                                        <span className="badge-dot"></span>
                                        {h_status}
                                    </span>
                                </div>
                                <div style={{"display": "flex", "justifyContent": "space-between", "fontSize": "13px"}}>
                                    <span className="text-secondary">Uptime</span>
                                    <span className="mono">{health["uptime_seconds"] or 0}s</span>
                                </div>
                                <div style={{"display": "flex", "justifyContent": "space-between", "fontSize": "13px"}}>
                                    <span className="text-secondary">PID</span>
                                    <span className="mono">{health["pid"] or "-"}</span>
                                </div>
                                <div style={{"display": "flex", "justifyContent": "space-between", "fontSize": "13px"}}>
                                    <span className="text-secondary">Python</span>
                                    <span className="mono">{health["python_version"] or "-"}</span>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>;
    }
}
