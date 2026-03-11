"""Sandbox page — execute Jac code interactively."""

sv import from ...main { run_sandbox, get_sandbox_history }

def:pub page() -> JsxElement {
    has code: str = "with entry {\n    print(42 + 58);\n}";
    has output: str = "-- output will appear here --";
    has timeout_sec: int = 10;
    has sessions: list = [];
    has loading: bool = True;
    has running: bool = False;

    async can with entry {
        try {
            result = root spawn get_sandbox_history(limit=10);
            if result.reports and result.reports.length > 0 {
                sessions = result.reports[0];
            }
        } except Exception as e {
            sessions = [];
        }
        loading = False;
    }

    async def handle_run() -> None {
        if not code.trim() { return; }
        running = True;
        output = "Executing...";
        try {
            result = root spawn run_sandbox(code=code, timeout_sec=timeout_sec);
            if result.reports and result.reports.length > 0 {
                resp = result.reports[0];
                output = resp["output"] or "(no output)";
            }
            # Refresh history
            h = root spawn get_sandbox_history(limit=10);
            if h.reports and h.reports.length > 0 {
                sessions = h.reports[0];
            }
        } except Exception as e {
            output = str(e);
        }
        running = False;
    }

    def load_session(session_id: str) -> None {
        for s in sessions {
            if s["session_id"] == session_id {
                code = s["code"];
                output = s["output"];
            }
        }
    }

    if loading {
        return <div className="page-loading">Loading sandbox...</div>;
    }

    return <div className="page">
        <div className="page-header">
            <h1>Sandbox</h1>
            <p className="subtitle">Execute Jac code interactively</p>
        </div>

        <div className="row">
            <div className="col">
                <div className="card">
                    <div className="card-title">Jac Code Editor</div>
                    <textarea
                        className="code-editor"
                        value={code}
                        onChange={lambda e: any -> None { code = e.target.value; }}
                        rows={12}
                    ></textarea>
                    <div style={{"display": "flex", "gap": "12px", "alignItems": "flex-end", "marginTop": "8px"}}>
                        <div className="form-group" style={{"marginBottom": "0", "width": "150px"}}>
                            <label>Timeout (sec)</label>
                            <input
                                type="number"
                                value={timeout_sec}
                                min={1}
                                max={30}
                                onChange={lambda e: any -> None { timeout_sec = parseInt(e.target.value) or 10; }}
                            />
                        </div>
                        <button
                            className="btn btn-primary"
                            onClick={lambda -> None { handle_run(); }}
                            disabled={running}
                        >
                            {running and "Running..." or "Run Code"}
                        </button>
                    </div>
                </div>
                <div className="card">
                    <div className="card-title">Output</div>
                    <div className="code-output">{output}</div>
                </div>
            </div>
            <div className="col">
                <div className="card">
                    <div className="card-title">Recent Sessions</div>
                    {sessions.length == 0 and (
                        <div className="empty">No sessions yet</div>
                    ) or (
                        <table>
                            <thead><tr><th>ID</th><th>Status</th><th>Time</th></tr></thead>
                            <tbody>
                                {[
                                    <tr
                                        key={s["session_id"]}
                                        style={{"cursor": "pointer"}}
                                        onClick={lambda -> None { load_session(s["session_id"]); }}
                                    >
                                        <td className="mono" style={{"fontSize": "11px"}}>{s["session_id"]}</td>
                                        <td><span className={"badge badge-" + s["status"]}>{s["status"]}</span></td>
                                        <td className="text-dim" style={{"fontSize": "11px"}}>{s["created_at"]}</td>
                                    </tr>
                                    for s in sessions
                                ]}
                            </tbody>
                        </table>
                    )}
                </div>
            </div>
        </div>
    </div>;
}
