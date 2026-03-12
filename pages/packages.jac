cl {
    sv import from ..main { list_packages, get_package_detail, install_package }

    def:pub page -> JsxElement {
        has packs: list = [],
            loading: bool = true,
            selected: any = None,
            installing: str = "",
            install_result: any = None,
            filter_category: str = "",
            search_query: str = "",
            copied_cmd: str = "";

        async can with entry {
            try {
                result = root spawn list_packages();
                if result.reports and len(result.reports) > 0 {
                    packs = result.reports[0];
                }
            } except Exception as e {
                print("Package list error:", e);
            }
            loading = false;
        }

        async def do_search -> None {
            loading = true;
            try {
                result = root spawn list_packages(category=filter_category, search=search_query);
                if result.reports and len(result.reports) > 0 {
                    packs = result.reports[0];
                }
            } except Exception as e {
                print("Search error:", e);
            }
            loading = false;
        }

        async def handle_install(pack_name: str) -> None {
            installing = pack_name;
            install_result = None;
            try {
                r = root spawn install_package(name=pack_name);
                if r.reports and len(r.reports) > 0 {
                    install_result = r.reports[0];
                }
            } except Exception as e {
                install_result = {"status": "error", "message": str(e)};
            }
            installing = "";
        }

        def copy_command(cmd: str) -> None {
            navigator.clipboard.writeText(cmd);
            copied_cmd = cmd;
            setTimeout(lambda -> None { copied_cmd = ""; }, 2000);
        }

        def get_difficulty_color(diff: str) -> str {
            if diff == "beginner" { return "#10b981"; }
            if diff == "intermediate" { return "#f59e0b"; }
            return "#ef4444";
        }

        def get_category_icon(cat: str) -> str {
            if cat == "AI" { return "⬣"; }
            if cat == "Starter" { return "▶"; }
            return "⚙";
        }

        if loading {
            return
                <div className="page-loading">
                    <div className="spinner"></div>
                    <div className="loading-text">Loading packages...</div>
                </div>;
        }

        return
            <div className="page">
                <div className="page-header">
                    <div className="page-header-left">
                        <h1>Packages</h1>
                        <div className="subtitle">Browse and install Jac application templates from jacpacks</div>
                    </div>
                    <div className="page-header-actions">
                        <span className="badge badge-info">{len(packs)} available</span>
                    </div>
                </div>

                <div style={{"display": "flex", "gap": "12px", "marginBottom": "20px"}}>
                    <input
                        type="text"
                        placeholder="Search packages..."
                        value={search_query}
                        onChange={lambda e: any -> None { search_query = e.target.value; do_search(); }}
                        style={{
                            "flex": "1",
                            "padding": "10px 14px",
                            "background": "var(--bg-secondary)",
                            "border": "1px solid var(--border)",
                            "borderRadius": "var(--radius)",
                            "color": "var(--text-primary)",
                            "fontSize": "14px"
                        }}
                    />
                    <div style={{"display": "flex", "gap": "6px"}}>
                        {[
                            <button
                                key={cat}
                                className={"btn " + ("btn-primary" if filter_category == cat else "btn-ghost")}
                                onClick={lambda -> None {
                                    filter_category = (filter_category == cat) and "" or cat;
                                    do_search();
                                }}
                                style={{"fontSize": "13px"}}
                            >
                                {cat or "All"}
                            </button>
                            for cat in ["", "Starter", "AI", "Developer Tools"]
                        ]}
                    </div>
                </div>

                {install_result and <div style={{
                    "padding": "16px",
                    "marginBottom": "20px",
                    "background": install_result["status"] == "error" and "#ef444418" or (install_result["status"] == "success" and "#10b98118" or "var(--bg-secondary)"),
                    "border": "1px solid " + (install_result["status"] == "error" and "#ef4444" or (install_result["status"] == "success" and "#10b981" or "var(--accent)")),
                    "borderRadius": "var(--radius)"
                }}>
                    <div style={{"display": "flex", "alignItems": "center", "gap": "8px", "marginBottom": "8px"}}>
                        <span style={{"fontSize": "18px"}}>
                            {install_result["status"] == "success" and "✓" or (install_result["status"] == "error" and "✗" or "ℹ")}
                        </span>
                        <div style={{"fontWeight": "600", "color": "var(--text-primary)"}}>
                            {install_result["status"] == "error" and "Installation Failed" or (install_result["status"] == "success" and "Installed Successfully" or install_result["package"])}
                        </div>
                        <button
                            className="btn btn-ghost btn-sm"
                            onClick={lambda -> None { install_result = None; }}
                            style={{"marginLeft": "auto", "fontSize": "11px"}}
                        >
                            Dismiss
                        </button>
                    </div>
                    <div style={{"fontSize": "13px", "color": "var(--text-secondary)", "marginBottom": "4px"}}>
                        {install_result["message"]}
                    </div>
                    {install_result["project_dir"] and <div style={{"fontSize": "12px", "color": "var(--text-muted)", "fontFamily": "var(--mono)"}}>
                        {install_result["project_dir"]}
                    </div>}
                    {install_result["command"] and <div style={{"marginTop": "8px"}}>
                        <div style={{"fontSize": "12px", "color": "var(--text-muted)", "marginBottom": "4px"}}>Or run manually:</div>
                        <div style={{"display": "flex", "gap": "8px", "alignItems": "center"}}>
                            <code style={{
                                "flex": "1",
                                "padding": "8px 12px",
                                "background": "var(--bg-primary)",
                                "border": "1px solid var(--border)",
                                "borderRadius": "var(--radius)",
                                "fontSize": "12px",
                                "fontFamily": "var(--mono)",
                                "color": "var(--accent)",
                                "overflowX": "auto"
                            }}>
                                {install_result["command"]}
                            </code>
                            <button
                                className="btn btn-ghost btn-sm"
                                onClick={lambda -> None { copy_command(install_result["command"]); }}
                            >
                                {copied_cmd == install_result["command"] and "Copied!" or "Copy"}
                            </button>
                        </div>
                    </div>}
                </div>}

                <div style={{
                    "display": "grid",
                    "gridTemplateColumns": "repeat(auto-fill, minmax(340px, 1fr))",
                    "gap": "16px"
                }}>
                    {[
                        <div key={p["name"]} className="card" style={{"cursor": "pointer", "transition": "border-color 0.2s", "border": selected and selected["name"] == p["name"] and "1px solid var(--accent)" or "1px solid var(--border)"}}>
                            <div style={{"display": "flex", "alignItems": "flex-start", "gap": "12px", "marginBottom": "12px"}}>
                                <div style={{
                                    "width": "40px",
                                    "height": "40px",
                                    "borderRadius": "10px",
                                    "background": "var(--accent)" + "18",
                                    "border": "1px solid var(--accent)" + "40",
                                    "display": "flex",
                                    "alignItems": "center",
                                    "justifyContent": "center",
                                    "fontSize": "18px",
                                    "flexShrink": "0"
                                }}>
                                    {get_category_icon(p["category"])}
                                </div>
                                <div style={{"flex": "1", "minWidth": "0"}}>
                                    <div style={{"fontWeight": "700", "fontSize": "15px", "color": "var(--text-primary)", "marginBottom": "2px"}}>{p["title"]}</div>
                                    <div style={{"display": "flex", "gap": "6px", "alignItems": "center"}}>
                                        <span className="badge" style={{"fontSize": "11px"}}>{p["category"]}</span>
                                        <span style={{"fontSize": "11px", "color": get_difficulty_color(p["difficulty"])}}>{p["difficulty"]}</span>
                                    </div>
                                </div>
                            </div>
                            <div style={{"fontSize": "13px", "color": "var(--text-secondary)", "lineHeight": "1.5", "marginBottom": "12px"}}>
                                {p["description"]}
                            </div>
                            <div style={{"display": "flex", "flexWrap": "wrap", "gap": "4px", "marginBottom": "12px"}}>
                                {[
                                    <span key={tag} style={{
                                        "fontSize": "11px",
                                        "padding": "2px 8px",
                                        "borderRadius": "10px",
                                        "background": "var(--bg-secondary)",
                                        "color": "var(--text-muted)"
                                    }}>
                                        {tag}
                                    </span>
                                    for tag in p["tags"]
                                ]}
                            </div>
                            <div style={{"display": "flex", "gap": "8px"}}>
                                <button
                                    className="btn btn-primary btn-sm"
                                    onClick={lambda -> None { handle_install(p["name"]); }}
                                    disabled={installing == p["name"]}
                                    style={{"flex": "1"}}
                                >
                                    {installing == p["name"] and "Installing..." or "Install"}
                                </button>
                                <a
                                    href={"https://github.com/jaseci-labs/jacpacks/tree/main/" + p["repo_path"]}
                                    target="_blank"
                                    className="btn btn-ghost btn-sm"
                                    style={{"textDecoration": "none"}}
                                >
                                    Source
                                </a>
                            </div>
                        </div>
                        for p in packs
                    ]}
                </div>

                {len(packs) == 0 and <div className="empty-state">
                    <div className="empty-icon">{"📦"}</div>
                    <div className="empty-title">No packages found</div>
                    <div className="empty-desc">{search_query and "Try a different search term" or "No packages match the selected filter"}</div>
                </div>}
            </div>;
    }
}
