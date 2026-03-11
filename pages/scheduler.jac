cl {
    sv import from ..main { list_schedules, create_schedule, toggle_schedule, delete_schedule }

    def:pub page -> JsxElement {
        has schedules: list = [],
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
                # Refresh
                result = root spawn list_schedules();
                if result.reports and len(result.reports) > 0 {
                    schedules = result.reports[0];
                }
                walker_name = "";
                cron_expr = "*/5 * * * *";
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

        if loading {
            return <div className="page-loading">Loading schedules...</div>;
        }

        return
            <div className="page">
                <div className="page-header">
                    <h1>Scheduler</h1>
                    <p className="subtitle">Manage cron jobs and triggers</p>
                </div>

                <div className="card">
                    <div className="card-title">New Schedule</div>
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
                    <button
                        className="btn btn-primary"
                        onClick={lambda -> None { handle_create(); }}
                        disabled={creating or not walker_name}
                    >
                        {"Creating..." if creating else "Create Schedule"}
                    </button>
                </div>

                <div className="card">
                    <div className="card-title">Schedules ({len(schedules)})</div>
                    {len(schedules) == 0
                    and <div className="empty">No schedules configured</div>
                    or <table>
                        <thead><tr><th>Walker</th><th>Cron</th><th>Status</th><th>Actions</th></tr></thead>
                        <tbody>
                            {[
                                <tr key={s.get("id", s.get("walker_name", ""))}>
                                    <td className="mono">{s.get("walker_name", "")}</td>
                                    <td className="mono">{s.get("cron_expr", "")}</td>
                                    <td>
                                        <span className={"badge " + ("badge-success" if s.get("enabled", false) else "badge-pending")}>
                                            {"active" if s.get("enabled", false) else "paused"}
                                        </span>
                                    </td>
                                    <td>
                                        <button
                                            className="btn btn-sm"
                                            onClick={lambda -> None { handle_toggle(s.get("id", "")); }}
                                            style={{"marginRight": "4px"}}
                                        >
                                            {"Pause" if s.get("enabled", false) else "Enable"}
                                        </button>
                                        <button
                                            className="btn btn-danger btn-sm"
                                            onClick={lambda -> None { handle_delete(s.get("id", "")); }}
                                        >
                                            Delete
                                        </button>
                                    </td>
                                </tr>
                                for s in schedules
                            ]}
                        </tbody>
                    </table>}
                </div>
            </div>;
    }
}
