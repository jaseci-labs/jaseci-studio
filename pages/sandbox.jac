cl {
    sv import from ..main { run_sandbox, get_sandbox_history }

    def:pub page -> JsxElement {
        has code: str = "walker hello {\n    can greet with `root entry {\n        report \"Hello from Jac!\";\n    }\n}\n",
            result: any = None,
            sessions: list = [],
            running: bool = false,
            loading: bool = true;

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
                # Refresh history
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
            return <div className="page-loading">Loading sandbox...</div>;
        }

        return
            <div className="page">
                <div className="page-header">
                    <h1>Sandbox</h1>
                    <p className="subtitle">Write and execute Jac code</p>
                </div>

                <div className="row">
                    <div className="col">
                        <div className="card">
                            <div className="card-title">Code Editor</div>
                            <textarea
                                className="code-editor"
                                value={code}
                                onChange={lambda e: any -> None { code = e.target.value; }}
                                style={{"minHeight": "250px"}}
                            />
                            <button
                                className="btn btn-primary"
                                onClick={lambda -> None { handle_run(); }}
                                disabled={running}
                                style={{"marginTop": "12px"}}
                            >
                                {"Running..." if running else "Run Code"}
                            </button>
                        </div>

                        {result and <div className="card">
                            <div className="card-title">Output</div>
                            <div className="code-output">
                                {JSON.stringify(result, None, 2)}
                            </div>
                        </div>}
                    </div>

                    <div className="col">
                        <div className="card">
                            <div className="card-title">History ({len(sessions)})</div>
                            {len(sessions) == 0
                            and <div className="empty">No sessions yet</div>
                            or <div>
                                {[
                                    <div
                                        key={s.get("executed_at", "")}
                                        className="card"
                                        style={{"cursor": "pointer", "padding": "12px"}}
                                        onClick={lambda -> None { code = s.get("code", ""); }}
                                    >
                                        <div style={{"display": "flex", "justifyContent": "space-between"}}>
                                            <span className={"badge badge-" + s.get("status", "")}>
                                                {s.get("status", "")}
                                            </span>
                                            <span className="text-dim" style={{"fontSize": "11px"}}>
                                                {s.get("executed_at", "")}
                                            </span>
                                        </div>
                                    </div>
                                    for s in sessions
                                ]}
                            </div>}
                        </div>
                    </div>
                </div>
            </div>;
    }
}
