cl {
    sv import from ..main { list_walkers, run_walker_test, get_run_history }

    def:pub page -> JsxElement {
        has walkers: list = [],
            selected: str = "",
            payload: str = "{}",
            result: any = None,
            history: list = [],
            running: bool = false,
            loading: bool = true;

        async can with entry {
            try {
                w_result = root spawn list_walkers();
                if w_result.reports and len(w_result.reports) > 0 {
                    walkers = w_result.reports[0];
                }
            } except Exception as e {
                print("Walker list error:", e);
            }

            try {
                h_result = root spawn get_run_history(limit=10);
                if h_result.reports and len(h_result.reports) > 0 {
                    history = h_result.reports[0];
                }
            } except Exception as e {
                print("History error:", e);
            }

            loading = false;
        }

        async def handle_run -> None {
            if not selected {
                return;
            }
            running = true;
            result = None;
            try {
                parsed = JSON.parse(payload);
                run_result = root spawn run_walker_test(
                    walker_name=selected,
                    payload=parsed
                );
                if run_result.reports and len(run_result.reports) > 0 {
                    result = run_result.reports[0];
                }
                # Refresh history
                h_result = root spawn get_run_history(limit=10);
                if h_result.reports and len(h_result.reports) > 0 {
                    history = h_result.reports[0];
                }
            } except Exception as e {
                result = {"error": str(e)};
            }
            running = false;
        }

        if loading {
            return <div className="page-loading">Loading workbench...</div>;
        }

        return
            <div className="page">
                <div className="page-header">
                    <h1>Walker Workbench</h1>
                    <p className="subtitle">Test and debug your walkers</p>
                </div>

                <div className="row">
                    <div className="col">
                        <div className="card">
                            <div className="card-title">Run Walker</div>
                            <div className="form-group">
                                <label>Walker</label>
                                <select
                                    value={selected}
                                    onChange={lambda e: any -> None { selected = e.target.value; }}
                                >
                                    <option value="">Select a walker...</option>
                                    {[
                                        <option key={w.get("name", "")} value={w.get("name", "")}>
                                            {w.get("name", "")}
                                        </option>
                                        for w in walkers
                                    ]}
                                </select>
                            </div>
                            <div className="form-group">
                                <label>Payload (JSON)</label>
                                <textarea
                                    className="code-editor"
                                    value={payload}
                                    onChange={lambda e: any -> None { payload = e.target.value; }}
                                />
                            </div>
                            <button
                                className="btn btn-primary"
                                onClick={lambda -> None { handle_run(); }}
                                disabled={running or not selected}
                            >
                                {"Running..." if running else "Run Walker"}
                            </button>
                        </div>

                        {result and <div className="card">
                            <div className="card-title">Result</div>
                            <div className="code-output">
                                {JSON.stringify(result, None, 2)}
                            </div>
                        </div>}
                    </div>

                    <div className="col">
                        <div className="card">
                            <div className="card-title">Run History</div>
                            {len(history) == 0
                            and <div className="empty">No runs yet</div>
                            or <table>
                                <thead><tr><th>Walker</th><th>Status</th><th>Time</th></tr></thead>
                                <tbody>
                                    {[
                                        <tr key={r.get("walker_name", "") + r.get("status", "")}>
                                            <td className="mono">{r.get("walker_name", "")}</td>
                                            <td><span className={"badge badge-" + r.get("status", "")}>{r.get("status", "")}</span></td>
                                            <td>{r.get("duration_ms", 0)}ms</td>
                                        </tr>
                                        for r in history
                                    ]}
                                </tbody>
                            </table>}
                        </div>
                    </div>
                </div>
            </div>;
    }
}
