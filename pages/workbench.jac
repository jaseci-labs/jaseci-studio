cl {
    sv import from ..main { list_walkers, run_walker_test, get_run_history }

    def:pub page -> JsxElement {
        has walkers: list = [],
            selected: str = "",
            selected_walker: any = None,
            payload: str = "{}",
            result: any = None,
            history: list = [],
            running: bool = false,
            loading: bool = true,
            tab: str = "result",
            copied: bool = false;

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

        def select_walker(name: str) -> None {
            selected = name;
            selected_walker = None;
            for w in walkers {
                if w["name"] == name {
                    selected_walker = w;
                    # Auto-generate payload template from walker params
                    params = w["params"] or [];
                    if len(params) > 0 {
                        template = {};
                        for p in params {
                            if p["default"] is not None and p["default"] != "None" {
                                template[p["name"]] = p["default"];
                            } else {
                                template[p["name"]] = "";
                            }
                        }
                        payload = JSON.stringify(template, None, 2);
                    } else {
                        payload = "{}";
                    }
                    break;
                }
            }
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

        def copy_result -> None {
            if result {
                text = JSON.stringify(result["reports"] or result["result"], None, 2);
                navigator.clipboard.writeText(text);
                copied = true;
                setTimeout(lambda -> None { copied = false; }, 2000);
            }
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
                        <div className="subtitle">Test, debug, and inspect walker execution in real time</div>
                    </div>
                    <div className="page-header-actions">
                        <span className="badge badge-info">
                            {len(walkers)} walkers discovered
                        </span>
                    </div>
                </div>

                <div className="row">
                    <div className="col">
                        <div className="card">
                            <div className="card-header">
                                <div className="card-title">Execute Walker</div>
                                {selected_walker and <span className="badge badge-info">{selected_walker["module"]}</span>}
                            </div>
                            <div className="form-group">
                                <label>Select Walker</label>
                                <select
                                    value={selected}
                                    onChange={lambda e: any -> None { select_walker(e.target.value); }}
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

                            {selected_walker and selected_walker["description"] and <div style={{"padding": "8px 12px", "background": "var(--bg-secondary)", "borderRadius": "var(--radius)", "marginBottom": "12px", "fontSize": "13px", "color": "var(--text-secondary)"}}>
                                {selected_walker["description"]}
                            </div>}

                            {selected_walker and selected_walker["params"] and len(selected_walker["params"]) > 0 and <div style={{"marginBottom": "12px"}}>
                                <div className="section-title">Parameters</div>
                                <div style={{"display": "flex", "flexWrap": "wrap", "gap": "6px"}}>
                                    {[
                                        <span key={p["name"]} className="badge" style={{"background": "var(--bg-secondary)", "color": "var(--text-primary)", "fontSize": "12px"}}>
                                            {p["name"]}: {p["type"]} {p["default"] and ("= " + p["default"]) or ""}
                                        </span>
                                        for p in selected_walker["params"]
                                    ]}
                                </div>
                            </div>}

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
                                {running and "Spawning..." or ("Spawn " + selected if selected else "Select a walker")}
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
                                    className={"tab-item" + (" active" if tab == "graph" else "")}
                                    onClick={lambda -> None { tab = "graph"; }}
                                >
                                    Graph Diff
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
                                and <div>
                                    <div style={{"display": "flex", "alignItems": "center", "gap": "8px", "marginBottom": "12px"}}>
                                        <span className={"badge " + ("badge-success" if result["status"] == "success" else "badge-error")}>
                                            {result["status"]}
                                        </span>
                                        <span style={{"fontSize": "12px", "color": "var(--text-muted)"}}>{result["duration_ms"]}ms</span>
                                        <button
                                            className="btn btn-ghost btn-sm"
                                            onClick={lambda -> None { copy_result(); }}
                                            style={{"marginLeft": "auto"}}
                                        >
                                            {copied and "Copied!" or "Copy"}
                                        </button>
                                    </div>
                                    {result["status"] == "success"
                                    and <div>
                                        <div className="section-title">Reports</div>
                                        <div className="code-output">{JSON.stringify(result["reports"] or result["result"], None, 2)}</div>
                                    </div>
                                    or <div>
                                        <div className="section-title">Error</div>
                                        <div className="code-output" style={{"color": "var(--error)"}}>{JSON.stringify(result["result"], None, 2)}</div>
                                    </div>}
                                </div>
                                or <div className="empty-state">
                                    <div className="empty-icon">{"⚙"}</div>
                                    <div className="empty-title">No result yet</div>
                                    <div className="empty-desc">Select a walker and click Spawn to execute it on root</div>
                                </div>
                            )}

                            {tab == "graph" and (
                                result and result["graph_diff"]
                                and <div>
                                    <div className="section-title">Nodes Created ({len(result["graph_diff"]["created"])})</div>
                                    {len(result["graph_diff"]["created"]) > 0
                                    and <div className="code-output">{JSON.stringify(result["graph_diff"]["created"], None, 2)}</div>
                                    or <div style={{"color": "var(--text-muted)", "fontSize": "13px", "marginBottom": "12px"}}>No new nodes</div>}
                                    <div className="section-title">Nodes Modified ({len(result["graph_diff"]["modified"])})</div>
                                    {len(result["graph_diff"]["modified"]) > 0
                                    and <div className="code-output">{JSON.stringify(result["graph_diff"]["modified"], None, 2)}</div>
                                    or <div style={{"color": "var(--text-muted)", "fontSize": "13px"}}>No modifications</div>}
                                </div>
                                or <div className="empty-state">
                                    <div className="empty-icon">{"⬡"}</div>
                                    <div className="empty-title">No graph diff</div>
                                    <div className="empty-desc">Run a walker to see what nodes were created or modified</div>
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
                                <div className="card-title">Discovered Walkers</div>
                                <div className="card-badge">{len(walkers)}</div>
                            </div>
                            {len(walkers) == 0
                            and <div className="empty">No walkers found in runtime</div>
                            or <div>
                                {[
                                    <div
                                        key={w["name"]}
                                        className={"history-item" + (" selected" if selected == w["name"] else "")}
                                        onClick={lambda -> None { select_walker(w["name"]); }}
                                        style={{"cursor": "pointer"}}
                                    >
                                        <div style={{"width": "8px", "height": "8px", "borderRadius": "50%", "background": (selected == w["name"] and "var(--accent)" or "var(--border-light)"), "flexShrink": "0"}}></div>
                                        <div className="history-info">
                                            <div className="history-name">{w["name"]}</div>
                                            <div className="history-meta">{w["description"] or w["module"]}</div>
                                        </div>
                                        {w["params"] and len(w["params"]) > 0 and <div style={{"fontSize": "11px", "color": "var(--text-muted)"}}>
                                            {len(w["params"])} params
                                        </div>}
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
