cl {
    sv import from ..main { list_schedules, create_schedule, toggle_schedule, delete_schedule }

    def:pub page -> JsxElement {
        has schedules: list = [],
            show_form: bool = false,
            walker_name: str = "",
            cron_expr: str = "*/5 * * * *",
            loading: bool = true,
            creating: bool = false;

        async can with entry {
            try {
                result = root spawn list_schedules();
                if result.reports and len(result.reports) > 0 {
                    schedules = result.reports[0];
                }
            } except Exception as e {
                print("Schedules error:", e);
            }
            loading = false;
        }

        async def handle_create -> None {
            if not walker_name {
                return;
            }
            creating = true;
            try {
                root spawn create_schedule(
                    walker_name=walker_name,
                    cron_expr=cron_expr
                );
                result = root spawn list_schedules();
                if result.reports and len(result.reports) > 0 {
                    schedules = result.reports[0];
                }
                walker_name = "";
                cron_expr = "*/5 * * * *";
                show_form = false;
            } except Exception as e {
                print("Create error:", e);
            }
            creating = false;
        }

        async def handle_toggle(schedule_id: str) -> None {
            try {
                root spawn toggle_schedule(schedule_id=schedule_id);
                result = root spawn list_schedules();
                if result.reports and len(result.reports) > 0 {
                    schedules = result.reports[0];
                }
            } except Exception as e {
                print("Toggle error:", e);
            }
        }

        async def handle_delete(schedule_id: str) -> None {
            try {
                root spawn delete_schedule(schedule_id=schedule_id);
                schedules = [s for s in schedules if s.get("id", "") != schedule_id];
            } except Exception as e {
                print("Delete error:", e);
            }
        }

        active_count = len([s for s in schedules if s.get("enabled", false)]);

        if loading {
            return
                <div className="page-loading">
                    <div className="spinner"></div>
                    <div className="loading-text">Loading schedules...</div>
                </div>;
        }

        return
            <div className="page">
                <div className="page-header">
                    <div className="page-header-left">
                        <h1>Scheduler</h1>
                        <div className="subtitle">Manage automated cron jobs and webhook triggers</div>
                    </div>
                    <div className="page-header-actions">
                        <button
                            className="btn btn-primary"
                            onClick={lambda -> None { show_form = not show_form; }}
                        >
                            {show_form and "Cancel" or "+ New Schedule"}
                        </button>
                    </div>
                </div>

                <div className="stats-grid" style={{"marginBottom": "24px"}}>
                    <div className="stat-card accent-stripe">
                        <div className="stat-value accent">{len(schedules)}</div>
                        <div className="stat-label">Total Schedules</div>
                    </div>
                    <div className="stat-card success-stripe">
                        <div className="stat-value success">{active_count}</div>
                        <div className="stat-label">Active</div>
                    </div>
                    <div className="stat-card warning-stripe">
                        <div className="stat-value warning">{len(schedules) - active_count}</div>
                        <div className="stat-label">Paused</div>
                    </div>
                </div>

                {show_form and <div className="card" style={{"marginBottom": "16px"}}>
                    <div className="card-header">
                        <div className="card-title">New Schedule</div>
                    </div>
                    <div className="row">
                        <div className="col">
                            <div className="form-group">
                                <label>Walker Name</label>
                                <input
                                    value={walker_name}
                                    onChange={lambda e: any -> None { walker_name = e.target.value; }}
                                    placeholder="get_dashboard"
                                />
                            </div>
                        </div>
                        <div className="col">
                            <div className="form-group">
                                <label>Cron Expression</label>
                                <input
                                    value={cron_expr}
                                    onChange={lambda e: any -> None { cron_expr = e.target.value; }}
                                    placeholder="*/5 * * * *"
                                />
                            </div>
                        </div>
                    </div>
                    <div style={{"fontSize": "11px", "color": "var(--text-muted)", "marginBottom": "12px"}}>
                        Examples: */5 * * * * (every 5 min) | 0 * * * * (hourly) | 0 0 * * * (daily)
                    </div>
                    <button
                        className="btn btn-primary"
                        onClick={lambda -> None { handle_create(); }}
                        disabled={creating or not walker_name}
                    >
                        {creating and "Creating..." or "Create Schedule"}
                    </button>
                </div>}

                {len(schedules) == 0
                and <div className="card">
                    <div className="empty-state">
                        <div className="empty-icon">:::</div>
                        <div className="empty-title">No schedules configured</div>
                        <div className="empty-desc">Create a schedule to automatically run walkers on a cron timer</div>
                    </div>
                </div>
                or <div>
                    {[
                        <div key={s.get("id", s.get("walker_name", ""))} className="schedule-item">
                            <div className="schedule-icon" style={{"color": (s.get("enabled", false) and "var(--success)" or "var(--text-muted)")}}>
                                {s.get("enabled", false) and ">>>" or "| |"}
                            </div>
                            <div className="schedule-info">
                                <div className="schedule-name">{s.get("walker_name", "")}</div>
                                <div className="schedule-meta">
                                    <span className="mono">{s.get("cron_expr", "")}</span>
                                    <span className={"badge " + ("badge-success" if s.get("enabled", false) else "badge-warning")}>
                                        <span className="badge-dot"></span>
                                        {s.get("enabled", false) and "active" or "paused"}
                                    </span>
                                </div>
                            </div>
                            <div className="schedule-actions">
                                <button
                                    className="btn btn-sm"
                                    onClick={lambda -> None { handle_toggle(s.get("id", "")); }}
                                >
                                    {s.get("enabled", false) and "Pause" or "Enable"}
                                </button>
                                <button
                                    className="btn btn-danger btn-sm"
                                    onClick={lambda -> None { handle_delete(s.get("id", "")); }}
                                >
                                    Delete
                                </button>
                            </div>
                        </div>
                        for s in schedules
                    ]}
                </div>}
            </div>;
    }
}
