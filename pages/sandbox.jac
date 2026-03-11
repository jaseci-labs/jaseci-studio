cl {
    sv import from ..main { run_sandbox, get_sandbox_history }

    def:pub page -> JsxElement {
        has code: str = "walker hello {\n    can greet with `root entry {\n        report \"Hello from Jac!\";\n    }\n}\n\nwith entry {\n    root spawn hello();\n}",
            result: any = None,
            sessions: list = [],
            running: bool = false,
            loading: bool = true,
            tab: str = "output";

        async can with entry {
            try {
                h_result = root spawn get_sandbox_history(limit=10);
                if h_result.reports and len(h_result.reports) > 0 {
                    sessions = h_result.reports[0];
                }
            } except Exception as e {
                print("History error:", e);
            }
            loading = false;
        }

        async def handle_run -> None {
            if not code.strip() {
                return;
            }
            running = true;
            result = None;
            try {
                r = root spawn run_sandbox(code=code);
                if r.reports and len(r.reports) > 0 {
                    result = r.reports[0];
                }
                tab = "output";
                h_result = root spawn get_sandbox_history(limit=10);
                if h_result.reports and len(h_result.reports) > 0 {
                    sessions = h_result.reports[0];
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
                    <div className="loading-text">Loading sandbox...</div>
                </div>;
        }

        return
            <div className="page">
                <div className="page-header">
                    <div className="page-header-left">
                        <h1>Sandbox</h1>
                        <div className="subtitle">Write, test, and iterate on Jac code in real time</div>
                    </div>
                    <div className="page-header-actions">
                        <button
                            className="btn btn-primary"
                            onClick={lambda -> None { handle_run(); }}
                            disabled={running or not code.strip()}
                        >
                            {running and "Executing..." or "Run Code"}
                        </button>
                    </div>
                </div>

                <div className="row">
                    <div className="col-2">
                        <div className="card" style={{"padding": "0", "overflow": "hidden"}}>
                            <div style={{"padding": "12px 16px", "borderBottom": "1px solid var(--border)", "display": "flex", "justifyContent": "space-between", "alignItems": "center"}}>
                                <div style={{"display": "flex", "alignItems": "center", "gap": "8px"}}>
                                    <span style={{"fontSize": "13px", "fontWeight": "600", "color": "var(--text-secondary)"}}>EDITOR</span>
                                    <span className="badge badge-info">Jac</span>
                                </div>
                                <button
                                    className="btn btn-ghost btn-sm"
                                    onClick={lambda -> None { code = ""; }}
                                >
                                    Clear
                                </button>
                            </div>
                            <textarea
                                className="code-editor"
                                value={code}
                                onChange={lambda e: any -> None { code = e.target.value; }}
                                style={{"minHeight": "320px", "border": "none", "borderRadius": "0", "padding": "16px", "resize": "vertical"}}
                                spellCheck={false}
                            />
                        </div>

                        <div className="card" style={{"padding": "0", "overflow": "hidden"}}>
                            <div className="tab-bar" style={{"padding": "0 16px"}}>
                                <div
                                    className={"tab-item" + (" active" if tab == "output" else "")}
                                    onClick={lambda -> None { tab = "output"; }}
                                >
                                    Output
                                </div>
                                <div
                                    className={"tab-item" + (" active" if tab == "history" else "")}
                                    onClick={lambda -> None { tab = "history"; }}
                                >
                                    History ({len(sessions)})
                                </div>
                            </div>

                            <div style={{"padding": "16px"}}>
                                {tab == "output" and (
                                    result
                                    and <div>
                                        <div style={{"display": "flex", "alignItems": "center", "gap": "8px", "marginBottom": "12px"}}>
                                            <span className={"badge " + ("badge-success" if result.get("status", "") == "success" else "badge-error")}>
                                                <span className="badge-dot"></span>
                                                {result.get("status", "unknown")}
                                            </span>
                                            {result.get("duration_ms", None) and <span className="text-dim" style={{"fontSize": "12px"}}>{result.get("duration_ms", 0)}ms</span>}
                                        </div>
                                        <div className="code-output">{JSON.stringify(result.get("output", result), None, 2)}</div>
                                    </div>
                                    or <div className="empty-state">
                                        <div className="empty-icon">[ ]</div>
                                        <div className="empty-title">Ready to run</div>
                                        <div className="empty-desc">Write some Jac code and click Run to see output</div>
                                    </div>
                                )}

                                {tab == "history" and (
                                    len(sessions) == 0
                                    and <div className="empty">No sessions yet</div>
                                    or <div>
                                        {[
                                            <div
                                                key={s.get("executed_at", "")}
                                                className="history-item"
                                                onClick={lambda -> None { code = s.get("code", ""); }}
                                            >
                                                <div className={"history-dot " + s.get("status", "")}></div>
                                                <div className="history-info">
                                                    <div className="history-name" style={{"fontFamily": "var(--mono)", "fontSize": "12px"}}>
                                                        {s.get("code", "").split("\n")[0]}
                                                    </div>
                                                    <div className="history-meta">{s.get("executed_at", "")}</div>
                                                </div>
                                                <div className="history-time">
                                                    <span className={"badge badge-" + s.get("status", "")}>{s.get("status", "")}</span>
                                                </div>
                                            </div>
                                            for s in sessions
                                        ]}
                                    </div>
                                )}
                            </div>
                        </div>
                    </div>

                    <div className="col">
                        <div className="card">
                            <div className="card-header">
                                <div className="card-title">Templates</div>
                            </div>
                            <div
                                className="history-item"
                                onClick={lambda -> None { code = "walker hello {\n    can greet with `root entry {\n        report \"Hello from Jac!\";\n    }\n}\n\nwith entry {\n    root spawn hello();\n}"; }}
                                style={{"cursor": "pointer"}}
                            >
                                <div className="history-info">
                                    <div className="history-name">Hello Walker</div>
                                    <div className="history-meta">Basic walker with report</div>
                                </div>
                            </div>
                            <div
                                className="history-item"
                                onClick={lambda -> None { code = "node Person {\n    has name: str,\n        age: int = 0;\n}\n\nedge Knows {}\n\nwalker find_people {\n    can discover with `root entry {\n        visit [-->];\n    }\n    can greet with Person entry {\n        report here.name;\n    }\n}\n\nwith entry {\n    p1 = root ++> Person(name=\"Alice\", age=30);\n    p2 = p1 ++> Person(name=\"Bob\", age=25);\n    root spawn find_people();\n}"; }}
                                style={{"cursor": "pointer"}}
                            >
                                <div className="history-info">
                                    <div className="history-name">Graph Traversal</div>
                                    <div className="history-meta">Nodes, edges, and walker traversal</div>
                                </div>
                            </div>
                            <div
                                className="history-item"
                                onClick={lambda -> None { code = "node Counter {\n    has count: int = 0;\n}\n\nwalker increment {\n    has amount: int = 1;\n    can inc with Counter entry {\n        here.count += self.amount;\n        report here.count;\n    }\n}\n\nwith entry {\n    c = root ++> Counter();\n    c spawn increment(amount=5);\n    c spawn increment(amount=3);\n}"; }}
                                style={{"cursor": "pointer"}}
                            >
                                <div className="history-info">
                                    <div className="history-name">Stateful Counter</div>
                                    <div className="history-meta">Node state mutation with walkers</div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>;
    }
}
