"""Workbench page — test and debug walkers."""

sv import from ...main { list_walkers, run_walker_test, get_run_history }

def:pub page() -> JsxElement {
    has walkers: list = [];
    has runs: list = [];
    has selected_walker: str = "";
    has payload_text: str = "{}";
    has run_result: any = None;
    has loading: bool = True;
    has running: bool = False;

    async can with entry {
        try {
            w_result = root spawn list_walkers();
            if w_result.reports and w_result.reports.length > 0 {
                walkers = w_result.reports[0];
            }
        } except Exception as e {
            walkers = [];
        }

        try {
            h_result = root spawn get_run_history(limit=20);
            if h_result.reports and h_result.reports.length > 0 {
                runs = h_result.reports[0];
            }
        } except Exception as e {
            runs = [];
        }

        loading = False;
    }

    async def handle_run() -> None {
        if not selected_walker { return; }
        running = True;
        run_result = None;
        try {
            payload = JSON.parse(payload_text);
            result = root spawn run_walker_test(
                walker_name=selected_walker,
                payload=payload
            );
            if result.reports and result.reports.length > 0 {
                run_result = result.reports[0];
            }
            # Refresh history
            h = root spawn get_run_history(limit=20);
            if h.reports and h.reports.length > 0 {
                runs = h.reports[0];
            }
        } except Exception as e {
            run_result = {"error": str(e)};
        }
        running = False;
    }

    if loading {
        return <div className="page-loading">Loading workbench...</div>;
    }

    return <div className="page">
        <div className="page-header">
            <h1>Workbench</h1>
            <p className="subtitle">Test and debug walkers</p>
        </div>

        <div className="row">
            <div className="col">
                <div className="card">
                    <div className="card-title">Run Walker</div>
                    <div className="form-group">
                        <label>Walker Name</label>
                        <select
                            value={selected_walker}
                            onChange={lambda e: any -> None { selected_walker = e.target.value; }}
                        >
                            <option value="">-- select --</option>
                            {[
                                <option key={w["name"]} value={w["name"]}>{w["name"]}</option>
                                for w in walkers
                            ]}
                        </select>
                    </div>
                    <div className="form-group">
                        <label>Payload (JSON)</label>
                        <textarea
                            value={payload_text}
                            onChange={lambda e: any -> None { payload_text = e.target.value; }}
                            rows={4}
                        ></textarea>
                    </div>
                    <button
                        className="btn btn-primary"
                        onClick={lambda -> None { handle_run(); }}
                        disabled={running or not selected_walker}
                    >
                        {running and "Running..." or "Run Walker"}
                    </button>

                    {run_result and (
                        <div className="code-output" style={{"marginTop": "12px"}}>
                            {JSON.stringify(run_result, None, 2)}
                        </div>
                    )}
                </div>
            </div>
            <div className="col">
                <div className="card">
                    <div className="card-title">Available Walkers ({walkers.length})</div>
                    {walkers.length == 0 and (
                        <div className="empty">No walkers found. Start a Jac app first.</div>
                    ) or (
                        <table>
                            <thead><tr><th>Name</th><th>Module</th></tr></thead>
                            <tbody>
                                {[
                                    <tr key={w["name"]}>
                                        <td>{w["name"]}</td>
                                        <td className="text-dim" style={{"fontSize": "11px"}}>{w["module"]}</td>
                                    </tr>
                                    for w in walkers
                                ]}
                            </tbody>
                        </table>
                    )}
                </div>
            </div>
        </div>

        <div className="card">
            <div className="card-title">Run History</div>
            {runs.length == 0 and (
                <div className="empty">No runs recorded yet</div>
            ) or (
                <table>
                    <thead><tr><th>Walker</th><th>Status</th><th>Duration</th><th>Time</th></tr></thead>
                    <tbody>
                        {[
                            <tr key={i}>
                                <td>{r["walker_name"]}</td>
                                <td><span className={"badge badge-" + r["status"]}>{r["status"]}</span></td>
                                <td>{r["duration_ms"]}ms</td>
                                <td className="text-dim" style={{"fontSize": "11px"}}>{r["started_at"]}</td>
                            </tr>
                            for (i, r) in enumerate(runs)
                        ]}
                    </tbody>
                </table>
            )}
        </div>
    </div>;
}
