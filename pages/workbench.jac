cl {
    sv import from ..main { list_walkers, run_walker_test, get_run_history }

    def:pub page -> JsxElement {
        has walkers: list = [],
            selected: str = "",
            payload: str = "{}",
            result: any = None,
            history: list = [],
            running: bool = false,
            loading: bool = true,
            tab: str = "result";

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
                h_result = root spawn get_run_history(limit=15);
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
                tab = "result";
                h_result = root spawn get_run_history(limit=15);
                if h_result.reports and len(h_result.reports) > 0 {
                    history = h_result.reports[0];
                }
            } except Exception as e {
                result = {"error": str(e)};
            }
            running = false;
        }

        if loading {
            return
                <div className="page-loading">
                    <div className="spinner"></div>
                    <div className="loading-text">Loading workbench...</div>
                </div>;
        }

        return
            <div className="page">
                <div className="page-header">
                    <div className="page-header-left">
                        <h1>Walker Workbench</h1>
                        <div className="subtitle">Test, debug, and inspect walker execution</div>
                    </div>
                    <div className="page-header-actions">
                        <span className="badge badge-info">
                            {len(walkers)} walkers available
                        </span>
                    </div>
                </div>

                <div className="row">
                    <div className="col">
                        <div className="card">
                            <div className="card-header">
                                <div className="card-title">Execute Walker</div>
                            </div>
                            <div className="form-group">
                                <label>Select Walker</label>
                                <select
                                    value={selected}
                                    onChange={lambda e: any -> None { selected = e.target.value; }}
                                >
                                    <option value="">Choose a walker...</option>
                                    {[
                                        <option key={w["name"]} value={w["name"]}>
                                            {w["name"]}
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
                                    placeholder='{"key": "value"}'
                                    style={{"minHeight": "160px"}}
                                />
                            </div>
                            <button
                                className={"btn btn-primary" + (" btn-lg" if selected else "")}
                                onClick={lambda -> None { handle_run(); }}
                                disabled={running or not selected}
                                style={{"width": "100%"}}
                            >
                                {running and "Running..." or ("Run " + selected if selected else "Select a walker")}
                            </button>
                        </div>

                        <div className="card">
                            <div className="tab-bar">
                                <div
                                    className={"tab-item" + (" active" if tab == "result" else "")}
                                    onClick={lambda -> None { tab = "result"; }}
                                >
                                    Result
                                </div>
                                <div
                                    className={"tab-item" + (" active" if tab == "history" else "")}
                                    onClick={lambda -> None { tab = "history"; }}
                                >
                                    History ({len(history)})
                                </div>
                            </div>

                            {tab == "result" and (
                                result
                                and <div className="code-output">{JSON.stringify(result, None, 2)}</div>
                                or <div className="empty-state">
                                    <div className="empty-icon">&gt;_</div>
                                    <div className="empty-title">No result yet</div>
                                    <div className="empty-desc">Select a walker and click Run to see output here</div>
                                </div>
                            )}

                            {tab == "history" and (
                                len(history) == 0
                                and <div className="empty">No runs recorded</div>
                                or <div>
                                    {[
                                        <div key={r["walker_name"] + r["executed_at"]} className="history-item">
                                            <div className={"history-dot " + r["status"]}></div>
                                            <div className="history-info">
                                                <div className="history-name">{r["walker_name"]}</div>
                                                <div className="history-meta">{r["duration_ms"]}ms</div>
                                            </div>
                                            <div className="history-time">
                                                <span className={"badge badge-" + r["status"]}>{r["status"]}</span>
                                            </div>
                                        </div>
                                        for r in history
                                    ]}
                                </div>
                            )}
                        </div>
                    </div>

                    <div className="col">
                        <div className="card">
                            <div className="card-header">
                                <div className="card-title">Available Walkers</div>
                                <div className="card-badge">{len(walkers)}</div>
                            </div>
                            {len(walkers) == 0
                            and <div className="empty">No walkers found</div>
                            or <div>
                                {[
                                    <div
                                        key={w["name"]}
                                        className="history-item"
                                        onClick={lambda -> None { selected = w["name"]; }}
                                        style={{"cursor": "pointer"}}
                                    >
                                        <div style={{"width": "8px", "height": "8px", "borderRadius": "50%", "background": (selected == w["name"] and "var(--accent)" or "var(--border-light)"), "flexShrink": "0"}}></div>
                                        <div className="history-info">
                                            <div className="history-name">{w["name"]}</div>
                                            <div className="history-meta">{w["type"]}</div>
                                        </div>
                                    </div>
                                    for w in walkers
                                ]}
                            </div>}
                        </div>
                    </div>
                </div>
            </div>;
    }
}
