cl {
    sv import from ..main { list_models, add_model, remove_model, get_cost_summary }

    def:pub page -> JsxElement {
        has models: list = [],
            costs: dict = {},
            show_form: bool = false,
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
                root spawn add_model(
                    name=name,
                    provider=provider,
                    model_id=model_id,
                    api_key=api_key
                );
                m_result = root spawn list_models();
                if m_result.reports and len(m_result.reports) > 0 {
                    models = m_result.reports[0];
                }
                name = "";
                model_id = "";
                api_key = "";
                show_form = false;
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

        provider_icon = {
            "openai": "O",
            "anthropic": "A",
            "ollama": "L",
            "google": "G",
            "cohere": "C"
        };

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
                        <div className="subtitle">Manage AI model configurations and monitor usage</div>
                    </div>
                    <div className="page-header-actions">
                        <button
                            className="btn btn-primary"
                            onClick={lambda -> None { show_form = not show_form; }}
                        >
                            {show_form and "Cancel" or "+ Add Model"}
                        </button>
                    </div>
                </div>

                <div className="stats-grid" style={{"marginBottom": "24px"}}>
                    <div className="stat-card accent-stripe">
                        <div className="stat-value accent">{len(models)}</div>
                        <div className="stat-label">Models Configured</div>
                    </div>
                    <div className="stat-card info-stripe">
                        <div className="stat-value info">{costs.get("total_requests", 0)}</div>
                        <div className="stat-label">Total Requests</div>
                    </div>
                    <div className="stat-card success-stripe">
                        <div className="stat-value success">${costs.get("total_cost_usd", 0)}</div>
                        <div className="stat-label">Total Cost (USD)</div>
                    </div>
                </div>

                {show_form and <div className="card" style={{"marginBottom": "16px"}}>
                    <div className="card-header">
                        <div className="card-title">New Model Configuration</div>
                    </div>
                    <div className="row">
                        <div className="col">
                            <div className="form-group">
                                <label>Display Name</label>
                                <input
                                    value={name}
                                    onChange={lambda e: any -> None { name = e.target.value; }}
                                    placeholder="my-gpt4"
                                />
                            </div>
                        </div>
                        <div className="col">
                            <div className="form-group">
                                <label>Provider</label>
                                <select
                                    value={provider}
                                    onChange={lambda e: any -> None { provider = e.target.value; }}
                                >
                                    <option value="openai">OpenAI</option>
                                    <option value="anthropic">Anthropic</option>
                                    <option value="ollama">Ollama (Local)</option>
                                    <option value="google">Google AI</option>
                                </select>
                            </div>
                        </div>
                    </div>
                    <div className="row">
                        <div className="col">
                            <div className="form-group">
                                <label>Model ID</label>
                                <input
                                    value={model_id}
                                    onChange={lambda e: any -> None { model_id = e.target.value; }}
                                    placeholder="gpt-4o, claude-sonnet-4-20250514, llama3..."
                                />
                            </div>
                        </div>
                        <div className="col">
                            <div className="form-group">
                                <label>API Key (optional for Ollama)</label>
                                <input
                                    type="password"
                                    value={api_key}
                                    onChange={lambda e: any -> None { api_key = e.target.value; }}
                                    placeholder="sk-..."
                                />
                            </div>
                        </div>
                    </div>
                    <button
                        className="btn btn-primary"
                        onClick={lambda -> None { handle_add(); }}
                        disabled={adding or not name or not model_id}
                    >
                        {adding and "Adding..." or "Add Model"}
                    </button>
                </div>}

                <div className="section-title">Models ({len(models)})</div>
                {len(models) == 0
                and <div className="card">
                    <div className="empty-state">
                        <div className="empty-icon">&lt;/&gt;</div>
                        <div className="empty-title">No models configured</div>
                        <div className="empty-desc">Add your first AI model to start routing requests through the gateway</div>
                    </div>
                </div>
                or <div>
                    {[
                        <div key={m.get("name", "")} className="model-card">
                            <div className="model-icon">
                                {provider_icon.get(m.get("provider", ""), "?")}
                            </div>
                            <div className="model-info">
                                <div className="model-name">{m.get("name", "")}</div>
                                <div className="model-meta">
                                    {m.get("provider", "")} / <span className="mono">{m.get("model_id", "")}</span>
                                </div>
                            </div>
                            <div className="model-actions">
                                <button
                                    className="btn btn-danger btn-sm"
                                    onClick={lambda -> None { handle_remove(m.get("name", "")); }}
                                >
                                    Remove
                                </button>
                            </div>
                        </div>
                        for m in models
                    ]}
                </div>}
            </div>;
    }
}
