cl {
    sv import from ..main { get_model_info, test_model_prompt }

    def:pub page -> JsxElement {
        has env_vars: list = [],
            active_model: str = "",
            provider: str = "",
            loading: bool = true,
            test_prompt: str = "Say hello in one sentence.",
            test_result: any = None,
            testing: bool = false;

        async can with entry {
            try {
                info_result = root spawn get_model_info();
                if info_result.reports and len(info_result.reports) > 0 {
                    data = info_result.reports[0];
                    env_vars = data["env_vars"] or [];
                    active_model = data["active_model"] or "(not set)";
                    provider = data["provider"] or "unknown";
                }
            } except Exception as e {
                print("Model info error:", e);
            }
            loading = false;
        }

        async def handle_test -> None {
            if not test_prompt { return; }
            testing = true;
            test_result = None;
            try {
                r = root spawn test_model_prompt(prompt=test_prompt);
                if r.reports and len(r.reports) > 0 {
                    test_result = r.reports[0];
                }
            } except Exception as e {
                test_result = {"status": "error", "output": str(e)};
            }
            testing = false;
        }

        def count_configured -> int {
            count: int = 0;
            for ev in env_vars {
                if ev["is_set"] { count = count + 1; }
            }
            return count;
        }

        if loading {
            return
                <div className="page-loading">
                    <div className="spinner"></div>
                    <div className="loading-text">Loading gateway...</div>
                </div>;
        }

        return
            <div className="page">
                <div className="page-header">
                    <div className="page-header-left">
                        <h1>AI Gateway</h1>
                        <div className="subtitle">Monitor AI model configuration and test LLM connectivity</div>
                    </div>
                    <div className="page-header-actions">
                        <span className="badge badge-info">
                            {count_configured()} vars configured
                        </span>
                    </div>
                </div>

                <div className="stats-grid" style={{"marginBottom": "24px"}}>
                    <div className="stat-card accent-stripe">
                        <div className="stat-value accent" style={{"fontSize": "16px"}}>{active_model}</div>
                        <div className="stat-label">Active Model (MTLLM_MODEL)</div>
                    </div>
                    <div className="stat-card info-stripe">
                        <div className="stat-value info">{provider}</div>
                        <div className="stat-label">Detected Provider</div>
                    </div>
                    <div className="stat-card success-stripe">
                        <div className="stat-value success">{count_configured()}/{len(env_vars)}</div>
                        <div className="stat-label">Env Vars Set</div>
                    </div>
                </div>

                <div className="row">
                    <div className="col">
                        <div className="card">
                            <div className="card-header">
                                <div className="card-title">Environment Variables</div>
                                <div className="card-badge">{len(env_vars)}</div>
                            </div>
                            {len(env_vars) == 0
                            and <div className="empty-state">
                                <div className="empty-icon">{"?"}</div>
                                <div className="empty-title">Could not read environment</div>
                            </div>
                            or <div>
                                {[
                                    <div key={ev["name"]} style={{
                                        "display": "flex",
                                        "alignItems": "center",
                                        "gap": "10px",
                                        "padding": "10px 0",
                                        "borderBottom": "1px solid var(--border)",
                                        "fontSize": "13px"
                                    }}>
                                        <div style={{
                                            "width": "8px",
                                            "height": "8px",
                                            "borderRadius": "50%",
                                            "background": ev["is_set"] and "#10b981" or "var(--border-light)",
                                            "flexShrink": "0"
                                        }}></div>
                                        <span style={{
                                            "fontFamily": "var(--mono)",
                                            "fontWeight": "600",
                                            "color": "var(--text-primary)",
                                            "minWidth": "180px"
                                        }}>
                                            {ev["name"]}
                                        </span>
                                        {ev["is_set"]
                                        and <span style={{"fontFamily": "var(--mono)", "color": "var(--text-secondary)"}}>
                                            {ev["value"]}
                                        </span>
                                        or <span style={{"color": "var(--text-muted)", "fontStyle": "italic"}}>
                                            not set
                                        </span>}
                                    </div>
                                    for ev in env_vars
                                ]}
                            </div>}

                            <div style={{"marginTop": "16px", "padding": "12px", "background": "var(--bg-secondary)", "borderRadius": "var(--radius)", "fontSize": "12px", "color": "var(--text-muted)"}}>
                                <div style={{"fontWeight": "600", "marginBottom": "6px", "color": "var(--text-secondary)"}}>How to configure</div>
                                <div>Set environment variables before starting your Jac app:</div>
                                <div className="code-output" style={{"marginTop": "8px", "fontSize": "12px"}}>
                                    <div>{"export MTLLM_MODEL=gpt-4o"}</div>
                                    <div>{"export OPENAI_API_KEY=sk-..."}</div>
                                    <div>{"jac start main.jac"}</div>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div className="col">
                        <div className="card">
                            <div className="card-header">
                                <div className="card-title">Test Model</div>
                            </div>
                            <div className="form-group">
                                <label>Prompt</label>
                                <textarea
                                    className="code-editor"
                                    value={test_prompt}
                                    onChange={lambda e: any -> None { test_prompt = e.target.value; }}
                                    placeholder="Enter a test prompt..."
                                    style={{"minHeight": "80px"}}
                                />
                            </div>
                            <button
                                className="btn btn-primary"
                                onClick={lambda -> None { handle_test(); }}
                                disabled={testing or not test_prompt}
                                style={{"width": "100%", "marginBottom": "16px"}}
                            >
                                {testing and "Sending..." or "Send Test Prompt"}
                            </button>

                            {test_result
                            and <div>
                                <div style={{"display": "flex", "alignItems": "center", "gap": "8px", "marginBottom": "8px"}}>
                                    <span className={"badge " + (test_result["status"] == "success" and "badge-success" or "badge-error")}>
                                        {test_result["status"]}
                                    </span>
                                </div>
                                <div className="code-output" style={{"whiteSpace": "pre-wrap", "fontSize": "13px"}}>
                                    {test_result["output"]}
                                </div>
                            </div>
                            or <div className="empty-state" style={{"padding": "24px"}}>
                                <div className="empty-icon">{">"}</div>
                                <div className="empty-title">No test run yet</div>
                                <div className="empty-desc">Send a test prompt to verify your LLM configuration is working</div>
                            </div>}
                        </div>
                    </div>
                </div>
            </div>;
    }
}
