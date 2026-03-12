cl {
    sv import from ..main { get_server_logs }

    def:pub page -> JsxElement {
        has entries: list = [],
            loading: bool = true,
            level_filter: str = "",
            auto_refresh: bool = false,
            refresh_count: int = 0;

        async can with entry {
            try {
                r = root spawn get_server_logs(limit=200);
                if r.reports and len(r.reports) > 0 {
                    entries = r.reports[0];
                }
            } except Exception as e {
                print("Logs error:", e);
            }
            loading = false;
        }

        async def refresh_logs -> None {
            try {
                r = root spawn get_server_logs(limit=200, level=level_filter);
                if r.reports and len(r.reports) > 0 {
                    entries = r.reports[0];
                }
            } except Exception as e {
                print("Refresh error:", e);
            }
            refresh_count = refresh_count + 1;
        }

        def set_level(lvl: str) -> None {
            if level_filter == lvl {
                level_filter = "";
            } else {
                level_filter = lvl;
            }
            refresh_logs();
        }

        def level_color(lvl: str) -> str {
            if lvl == "ERROR" or lvl == "CRITICAL" { return "#ef4444"; }
            if lvl == "WARNING" { return "#f59e0b"; }
            if lvl == "INFO" { return "#10b981"; }
            if lvl == "DEBUG" { return "#6366f1"; }
            return "var(--text-secondary)";
        }

        def format_time(ts: any) -> str {
            d = Date(ts * 1000);
            h = d.getHours();
            m = d.getMinutes();
            s = d.getSeconds();
            return ("" + h + ":" + m + ":" + s);
        }

        if loading {
            return
                <div className="page-loading">
                    <div className="spinner"></div>
                    <div className="loading-text">Loading logs...</div>
                </div>;
        }

        return
            <div className="page">
                <div className="page-header">
                    <div className="page-header-left">
                        <h1>Server Logs</h1>
                        <div className="subtitle">Real-time server log output for debugging</div>
                    </div>
                    <div className="page-header-actions">
                        <button
                            className="btn btn-sm"
                            onClick={lambda -> None { refresh_logs(); }}
                            style={{"fontSize": "12px"}}
                        >
                            {"Refresh"}
                        </button>
                        <span className="badge badge-info" style={{"marginLeft": "6px"}}>
                            {len(entries)} entries
                        </span>
                    </div>
                </div>

                <div className="card" style={{"marginBottom": "16px", "padding": "10px 16px"}}>
                    <div style={{"display": "flex", "alignItems": "center", "gap": "8px"}}>
                        <span style={{"fontSize": "12px", "color": "var(--text-muted)", "marginRight": "4px"}}>Filter:</span>
                        {[
                            <div
                                key={lvl}
                                onClick={lambda -> None { set_level(lvl); }}
                                style={{
                                    "padding": "3px 10px",
                                    "borderRadius": "12px",
                                    "fontSize": "11px",
                                    "fontWeight": "600",
                                    "cursor": "pointer",
                                    "border": "1px solid " + level_color(lvl),
                                    "background": level_filter == lvl and (level_color(lvl) + "30") or "transparent",
                                    "color": level_color(lvl),
                                    "opacity": (not level_filter or level_filter == lvl) and "1" or "0.4"
                                }}
                            >
                                {lvl}
                            </div>
                            for lvl in ["DEBUG", "INFO", "WARNING", "ERROR"]
                        ]}
                        {level_filter and <div
                            onClick={lambda -> None { level_filter = ""; refresh_logs(); }}
                            style={{
                                "padding": "3px 10px",
                                "borderRadius": "12px",
                                "fontSize": "11px",
                                "cursor": "pointer",
                                "color": "var(--text-muted)",
                                "border": "1px solid var(--border)"
                            }}
                        >
                            {"Clear"}
                        </div>}
                    </div>
                </div>

                <div className="card">
                    {len(entries) == 0
                    and <div className="empty-state">
                        <div className="empty-icon">{">"}</div>
                        <div className="empty-title">No log entries</div>
                        <div className="empty-desc">
                            {level_filter and ("No " + level_filter + " entries found. Try clearing the filter.") or "Log entries will appear here as your app runs."}
                        </div>
                    </div>
                    or <div style={{"fontFamily": "var(--mono)", "fontSize": "12px", "lineHeight": "1.8"}}>
                        {[
                            <div
                                key={entry["timestamp"]}
                                style={{
                                    "display": "flex",
                                    "gap": "10px",
                                    "padding": "3px 0",
                                    "borderBottom": "1px solid var(--border)",
                                    "alignItems": "flex-start"
                                }}
                            >
                                <span style={{"color": "var(--text-muted)", "flexShrink": "0", "width": "60px"}}>
                                    {format_time(entry["timestamp"])}
                                </span>
                                <span style={{
                                    "flexShrink": "0",
                                    "width": "55px",
                                    "fontWeight": "700",
                                    "color": level_color(entry["level"]),
                                    "fontSize": "10px",
                                    "padding": "2px 0"
                                }}>
                                    {entry["level"]}
                                </span>
                                <span style={{
                                    "color": "var(--text-muted)",
                                    "flexShrink": "0",
                                    "width": "120px",
                                    "overflow": "hidden",
                                    "textOverflow": "ellipsis",
                                    "whiteSpace": "nowrap",
                                    "fontSize": "11px"
                                }}>
                                    {entry["logger"]}
                                </span>
                                <span style={{
                                    "flex": "1",
                                    "color": entry["level"] == "ERROR" and "#ef4444" or (entry["level"] == "WARNING" and "#f59e0b" or "var(--text-primary)"),
                                    "whiteSpace": "pre-wrap",
                                    "wordBreak": "break-all"
                                }}>
                                    {entry["message"]}
                                </span>
                            </div>
                            for entry in entries
                        ]}
                    </div>}
                </div>
            </div>;
    }
}
