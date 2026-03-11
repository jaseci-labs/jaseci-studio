"""Scheduler page — cron jobs and webhook triggers."""

sv import from ...main { list_schedules, create_schedule, toggle_schedule, delete_schedule }

def:pub page() -> JsxElement {
    has schedules: list = [];
    has loading: bool = True;
    has sched_name: str = "";
    has walker_name: str = "";
    has cron_expr: str = "";
    has webhook_path: str = "";
    has payload_text: str = "{}";
    has message: str = "";

    async can with entry {
        await load_schedules();
    }

    async def load_schedules() -> None {
        loading = True;
        try {
            result = root spawn list_schedules();
            if result.reports and result.reports.length > 0 {
                schedules = result.reports[0];
            }
        } except Exception as e {
            schedules = [];
        }
        loading = False;
    }

    async def handle_create() -> None {
        if not sched_name { message = "Name required"; return; }
        try {
            payload = JSON.parse(payload_text);
            result = root spawn create_schedule(
                name=sched_name,
                walker_name=walker_name,
                cron_expr=cron_expr,
                webhook_path=webhook_path,
                payload=payload
            );
            if result.reports and result.reports.length > 0 {
                resp = result.reports[0];
                if "error" in resp {
                    message = resp["error"];
                } else {
                    message = f"Schedule '{sched_name}' created";
                    sched_name = "";
                    walker_name = "";
                    cron_expr = "";
                    webhook_path = "";
                    payload_text = "{}";
                    await load_schedules();
                }
            }
        } except Exception as e {
            message = str(e);
        }
    }

    async def handle_toggle(name: str, enabled: bool) -> None {
        root spawn toggle_schedule(name=name, enabled=enabled);
        await load_schedules();
    }

    async def handle_delete(name: str) -> None {
        root spawn delete_schedule(name=name);
        message = f"Schedule '{name}' deleted";
        await load_schedules();
    }

    if loading {
        return <div className="page-loading">Loading scheduler...</div>;
    }

    return <div className="page">
        <div className="page-header">
            <h1>Scheduler</h1>
            <p className="subtitle">Cron jobs and webhook triggers</p>
        </div>

        {message and <div className="toast-inline">{message}</div>}

        <div className="row">
            <div className="col">
                <div className="card">
                    <div className="card-title">Create Schedule</div>
                    <div className="form-group">
                        <label>Name</label>
                        <input value={sched_name} onChange={lambda e: any -> None { sched_name = e.target.value; }} placeholder="daily-report" />
                    </div>
                    <div className="form-group">
                        <label>Walker Name</label>
                        <input value={walker_name} onChange={lambda e: any -> None { walker_name = e.target.value; }} placeholder="GenerateReport" />
                    </div>
                    <div className="form-group">
                        <label>Cron Expression</label>
                        <input value={cron_expr} onChange={lambda e: any -> None { cron_expr = e.target.value; }} placeholder="0 9 * * *" />
                    </div>
                    <div className="form-group">
                        <label>Webhook Path (optional)</label>
                        <input value={webhook_path} onChange={lambda e: any -> None { webhook_path = e.target.value; }} placeholder="/hooks/my-trigger" />
                    </div>
                    <div className="form-group">
                        <label>Payload (JSON)</label>
                        <textarea value={payload_text} onChange={lambda e: any -> None { payload_text = e.target.value; }} rows={3}></textarea>
                    </div>
                    <button className="btn btn-primary" onClick={lambda -> None { handle_create(); }}>Create</button>
                </div>
            </div>
            <div className="col">
                <div className="card">
                    <div className="card-title">Schedules ({schedules.length})</div>
                    {schedules.length == 0 and (
                        <div className="empty">No schedules configured</div>
                    ) or (
                        <table>
                            <thead><tr><th>Name</th><th>Walker</th><th>Cron</th><th>Status</th><th></th></tr></thead>
                            <tbody>
                                {[
                                    <tr key={s["name"]}>
                                        <td>{s["name"]}</td>
                                        <td>{s["walker_name"]}</td>
                                        <td className="mono" style={{"fontSize": "11px"}}>{s["cron_expr"] or s["webhook_path"] or "-"}</td>
                                        <td>
                                            <span className={"badge " + (s["enabled"] and "badge-success" or "badge-error")}>
                                                {s["enabled"] and "on" or "off"}
                                            </span>
                                        </td>
                                        <td>
                                            <button className="btn btn-sm" onClick={lambda -> None { handle_toggle(s["name"], not s["enabled"]); }}>
                                                {s["enabled"] and "Disable" or "Enable"}
                                            </button>
                                            <button className="btn btn-danger btn-sm" style={{"marginLeft": "4px"}} onClick={lambda -> None { handle_delete(s["name"]); }}>
                                                Delete
                                            </button>
                                        </td>
                                    </tr>
                                    for s in schedules
                                ]}
                            </tbody>
                        </table>
                    )}
                </div>
            </div>
        </div>
    </div>;
}
