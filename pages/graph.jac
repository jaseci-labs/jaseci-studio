cl {
    sv import from ..main { inspect_graph }

    def:pub page -> JsxElement {
        has nodes: list = [],
            edges: list = [],
            selected: any = None,
            loading: bool = true;

        async can with entry {
            try {
                result = root spawn inspect_graph();
                if result.reports and len(result.reports) > 0 {
                    data = result.reports[0];
                    nodes = data.get("nodes", []);
                    edges = data.get("edges", []);
                }
            } except Exception as e {
                print("Graph error:", e);
            }
            loading = false;
        }

        if loading {
            return
                <div className="page-loading">
                    <div className="spinner"></div>
                    <div className="loading-text">Loading graph...</div>
                </div>;
        }

        return
            <div className="page">
                <div className="page-header">
                    <div className="page-header-left">
                        <h1>Graph Explorer</h1>
                        <div className="subtitle">Browse and inspect your application graph</div>
                    </div>
                    <div className="page-header-actions">
                        <span className="badge badge-info">{len(nodes)} nodes</span>
                        <span className="badge badge-info" style={{"marginLeft": "6px"}}>{len(edges)} edges</span>
                    </div>
                </div>

                {len(nodes) == 0 and <div className="card">
                    <div className="empty-state">
                        <div className="empty-icon">o-o</div>
                        <div className="empty-title">Graph is empty</div>
                        <div className="empty-desc">Run init_studio from the Workbench to bootstrap the Studio graph, then come back here to explore it.</div>
                    </div>
                </div>}

                {len(nodes) > 0 and <div className="row">
                    <div className="col-2">
                        <div className="card">
                            <div className="card-header">
                                <div className="card-title">Nodes</div>
                                <div className="card-badge">{len(nodes)}</div>
                            </div>
                            <div className="graph-grid">
                                {[
                                    <div
                                        key={n.get("id", "")}
                                        className={"graph-node-card" + (" root-node" if n.get("type", "") == "Root" else "") + (" selected" if selected and selected.get("id", "") == n.get("id", "") else "")}
                                        onClick={lambda -> None { selected = n; }}
                                    >
                                        <div className="node-type">{n.get("type", "unknown")}</div>
                                        <div className="node-id">{n.get("id", "")}</div>
                                    </div>
                                    for n in nodes
                                ]}
                            </div>
                        </div>

                        <div className="card">
                            <div className="card-header">
                                <div className="card-title">Edges</div>
                                <div className="card-badge">{len(edges)}</div>
                            </div>
                            {len(edges) == 0
                            and <div className="empty">No edges</div>
                            or <table>
                                <thead><tr><th>Source</th><th></th><th>Target</th><th>Type</th></tr></thead>
                                <tbody>
                                    {[
                                        <tr key={e.get("from", "") + e.get("to", "")}>
                                            <td className="mono truncate" style={{"maxWidth": "120px"}}>{e.get("from", "")}</td>
                                            <td style={{"color": "var(--text-muted)", "textAlign": "center"}}>-&gt;</td>
                                            <td className="mono truncate" style={{"maxWidth": "120px"}}>{e.get("to", "")}</td>
                                            <td><span className="badge badge-info">{e.get("type", "")}</span></td>
                                        </tr>
                                        for e in edges
                                    ]}
                                </tbody>
                            </table>}
                        </div>
                    </div>

                    <div className="col">
                        <div className="card" style={{"position": "sticky", "top": "28px"}}>
                            <div className="card-header">
                                <div className="card-title">Inspector</div>
                            </div>
                            {selected
                            and <div>
                                <div style={{"display": "flex", "alignItems": "center", "gap": "10px", "marginBottom": "16px"}}>
                                    <div style={{"width": "36px", "height": "36px", "borderRadius": "var(--radius)", "background": (selected.get("type", "") == "Root" and "var(--success-bg)" or "var(--info-bg)"), "display": "flex", "alignItems": "center", "justifyContent": "center", "fontSize": "14px", "fontWeight": "600", "color": (selected.get("type", "") == "Root" and "var(--success)" or "var(--info)")}}>
                                        {selected.get("type", "?")[0]}
                                    </div>
                                    <div>
                                        <div style={{"fontWeight": "600", "fontSize": "15px"}}>{selected.get("type", "unknown")}</div>
                                        <div className="mono" style={{"fontSize": "11px", "color": "var(--text-muted)"}}>{selected.get("id", "")}</div>
                                    </div>
                                </div>
                                <div className="section-title">Properties</div>
                                <div className="code-output">
                                    {JSON.stringify(selected.get("props", {}), None, 2)}
                                </div>
                            </div>
                            or <div className="empty-state">
                                <div className="empty-icon">?</div>
                                <div className="empty-title">No node selected</div>
                                <div className="empty-desc">Click on a node card to inspect its properties</div>
                            </div>}
                        </div>
                    </div>
                </div>}
            </div>;
    }
}
