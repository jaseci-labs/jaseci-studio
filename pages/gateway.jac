cl {
    sv import from ..main { list_models, add_model, remove_model, get_cost_summary }

    def:pub page -> JsxElement {
        has models: list = [],
            costs: dict = {},
            name: str = "",
            provider: str = "openai",
            model_id: str = "",
            api_key: str = "",
            adding: bool = false,
            loading: bool = true;

        async can with entry {
            try {
                m_result = root spawn list_models();
                if m_result.reports and len(m_result.reports) > 0 {
                    models = m_result.reports[0];
                }
            } except Exception as e {
                print("Models error:", e);
            }

            try {
                c_result = root spawn get_cost_summary();
                if c_result.reports and len(c_result.reports) > 0 {
                    costs = c_result.reports[0];
                }
            } except Exception as e {
                print("Cost error:", e);
            }

            loading = false;
        }

        async def handle_add -> None {
            if not name or not model_id {
                return;
            }
            adding = true;
            try {
                result = root spawn add_model(
                    name=name,
                    provider=provider,
                    model_id=model_id,
                    api_key=api_key
                );
                # Refresh
                m_result = root spawn list_models();
                if m_result.reports and len(m_result.reports) > 0 {
                    models = m_result.reports[0];
                }
                name = "";
                model_id = "";
                api_key = "";
            } except Exception as e {
                print("Add model error:", e);
            }
            adding = false;
        }

        async def handle_remove(model_name: str) -> None {
            try {
                root spawn remove_model(name=model_name);
                models = [m for m in models if m.get("name", "") != model_name];
            } except Exception as e {
                print("Remove error:", e);
            }
        }

        if loading {
            return <div className="page-loading">Loading gateway...</div>;
        }

        return
            <div className="page">
                <div className="page-header">
                    <h1>AI Gateway</h1>
                    <p className="subtitle">Manage AI model configurations</p>
                </div>

                <div className="row">
                    <div className="col">
                        <div className="card">
                            <div className="card-title">Add Model</div>
                            <div className="form-group">
                                <label>Name</label>
                                <input
                                    value={name}
                                    onChange={lambda e: any -> None { name = e.target.value; }}
                                    placeholder="my-gpt4"
                                />
                            </div>
                            <div className="form-group">
                                <label>Provider</label>
                                <select
                                    value={provider}
                                    onChange={lambda e: any -> None { provider = e.target.value; }}
                                >
                                    <option value="openai">OpenAI</option>
                                    <option value="anthropic">Anthropic</option>
                                    <option value="ollama">Ollama</option>
                                </select>
                            </div>
                            <div className="form-group">
                                <label>Model ID</label>
                                <input
                                    value={model_id}
                                    onChange={lambda e: any -> None { model_id = e.target.value; }}
                                    placeholder="gpt-4o"
                                />
                            </div>
                            <div className="form-group">
                                <label>API Key</label>
                                <input
                                    type="password"
                                    value={api_key}
                                    onChange={lambda e: any -> None { api_key = e.target.value; }}
                                    placeholder="sk-..."
                                />
                            </div>
                            <button
                                className="btn btn-primary"
                                onClick={lambda -> None { handle_add(); }}
                                disabled={adding or not name or not model_id}
                            >
                                {"Adding..." if adding else "Add Model"}
                            </button>
                        </div>
                    </div>

                    <div className="col">
                        <div className="card">
                            <div className="card-title">Models ({len(models)})</div>
                            {len(models) == 0
                            and <div className="empty">No models configured</div>
                            or <table>
                                <thead><tr><th>Name</th><th>Provider</th><th>Model</th><th></th></tr></thead>
                                <tbody>
                                    {[
                                        <tr key={m.get("name", "")}>
                                            <td className="mono">{m.get("name", "")}</td>
                                            <td>{m.get("provider", "")}</td>
                                            <td className="mono">{m.get("model_id", "")}</td>
                                            <td>
                                                <button
                                                    className="btn btn-danger btn-sm"
                                                    onClick={lambda -> None { handle_remove(m.get("name", "")); }}
                                                >
                                                    Remove
                                                </button>
                                            </td>
                                        </tr>
                                        for m in models
                                    ]}
                                </tbody>
                            </table>}
                        </div>

                        <div className="card">
                            <div className="card-title">Cost Summary</div>
                            <div className="stats-grid">
                                <div className="stat-card">
                                    <div className="stat-value">{costs.get("total_requests", 0)}</div>
                                    <div className="stat-label">Total Requests</div>
                                </div>
                                <div className="stat-card">
                                    <div className="stat-value">${costs.get("total_cost_usd", 0)}</div>
                                    <div className="stat-label">Total Cost</div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>;
    }
}
