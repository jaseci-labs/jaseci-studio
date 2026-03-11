"""AI Gateway page — model configuration and cost tracking."""

sv import from ...main { list_models, add_model, remove_model, get_cost_summary }

def:pub page() -> JsxElement {
    has models: list = [];
    has costs: list = [];
    has loading: bool = True;
    has model_id: str = "";
    has provider: str = "";
    has api_key_env: str = "";
    has max_tokens: int = 4096;
    has temperature: float = 0.7;
    has message: str = "";

    async can with entry {
        await load_data();
    }

    async def load_data() -> None {
        loading = True;
        try {
            m_result = root spawn list_models();
            if m_result.reports and m_result.reports.length > 0 {
                models = m_result.reports[0];
            }
        } except Exception as e {
            models = [];
        }

        try {
            c_result = root spawn get_cost_summary();
            if c_result.reports and c_result.reports.length > 0 {
                costs = c_result.reports[0];
            }
        } except Exception as e {
            costs = [];
        }
        loading = False;
    }

    async def handle_add() -> None {
        if not model_id { message = "Model ID required"; return; }
        try {
            result = root spawn add_model(
                model_id=model_id,
                provider=provider,
                api_key_env=api_key_env,
                max_tokens=max_tokens,
                temperature=temperature
            );
            if result.reports and result.reports.length > 0 {
                resp = result.reports[0];
                if "error" in resp {
                    message = resp["error"];
                } else {
                    message = f"Model {model_id} added";
                    model_id = "";
                    provider = "";
                    api_key_env = "";
                    await load_data();
                }
            }
        } except Exception as e {
            message = str(e);
        }
    }

    async def handle_delete(mid: str) -> None {
        try {
            root spawn remove_model(model_id=mid);
            message = f"Model {mid} deleted";
            await load_data();
        } except Exception as e {
            message = str(e);
        }
    }

    if loading {
        return <div className="page-loading">Loading gateway...</div>;
    }

    return <div className="page">
        <div className="page-header">
            <h1>AI Gateway</h1>
            <p className="subtitle">Model configuration and cost tracking</p>
        </div>

        {message and <div className="toast-inline">{message}</div>}

        <div className="row">
            <div className="col">
                <div className="card">
                    <div className="card-title">Add Model</div>
                    <div className="form-group">
                        <label>Model ID</label>
                        <input value={model_id} onChange={lambda e: any -> None { model_id = e.target.value; }} placeholder="gpt-4o" />
                    </div>
                    <div className="form-group">
                        <label>Provider</label>
                        <input value={provider} onChange={lambda e: any -> None { provider = e.target.value; }} placeholder="openai" />
                    </div>
                    <div className="form-group">
                        <label>API Key Env Var</label>
                        <input value={api_key_env} onChange={lambda e: any -> None { api_key_env = e.target.value; }} placeholder="OPENAI_API_KEY" />
                    </div>
                    <div className="form-group">
                        <label>Max Tokens</label>
                        <input type="number" value={max_tokens} onChange={lambda e: any -> None { max_tokens = parseInt(e.target.value) or 4096; }} />
                    </div>
                    <div className="form-group">
                        <label>Temperature</label>
                        <input type="number" step="0.1" value={temperature} onChange={lambda e: any -> None { temperature = parseFloat(e.target.value) or 0.7; }} />
                    </div>
                    <button className="btn btn-primary" onClick={lambda -> None { handle_add(); }}>Add Model</button>
                </div>
            </div>
            <div className="col">
                <div className="card">
                    <div className="card-title">Configured Models ({models.length})</div>
                    {models.length == 0 and (
                        <div className="empty">No models configured</div>
                    ) or (
                        <table>
                            <thead><tr><th>Model</th><th>Provider</th><th>Tokens</th><th></th></tr></thead>
                            <tbody>
                                {[
                                    <tr key={m["model_id"]}>
                                        <td>{m["model_id"]}</td>
                                        <td>{m["provider"]}</td>
                                        <td>{m["max_tokens"]}</td>
                                        <td>
                                            <button className="btn btn-danger btn-sm" onClick={lambda -> None { handle_delete(m["model_id"]); }}>
                                                Delete
                                            </button>
                                        </td>
                                    </tr>
                                    for m in models
                                ]}
                            </tbody>
                        </table>
                    )}
                </div>

                <div className="card">
                    <div className="card-title">Cost Summary</div>
                    {costs.length == 0 and (
                        <div className="empty">No cost data yet</div>
                    ) or (
                        <table>
                            <thead><tr><th>Model</th><th>Requests</th><th>Tokens</th><th>Cost</th></tr></thead>
                            <tbody>
                                {[
                                    <tr key={c["model_id"]}>
                                        <td>{c["model_id"]}</td>
                                        <td>{c["request_count"]}</td>
                                        <td>{c["total_input_tokens"] + c["total_output_tokens"]}</td>
                                        <td>${c["total_cost_usd"].toFixed(4)}</td>
                                    </tr>
                                    for c in costs
                                ]}
                            </tbody>
                        </table>
                    )}
                </div>
            </div>
        </div>
    </div>;
}
