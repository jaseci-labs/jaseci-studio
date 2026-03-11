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
            return <div className="page-loading">Loading graph...</div>;
        }

        return
            <div className="page">
                <div className="page-header">
                    <h1>Graph Explorer</h1>
                    <p className="subtitle">Visualize your application graph</p>
                </div>

                <div className="row">
                    <div className="col">
                        <div className="card">
                            <div className="card-title">Nodes ({len(nodes)})</div>
                            {len(nodes) == 0
                            and <div className="empty">No nodes found. Run init_studio first.</div>
                            or <div className="graph-grid">
                                {[
                                    <div
                                        key={n.get("id", "")}
                                        className={"graph-node-card" + (" root-node" if n.get("type", "") == "Root" else "")}
                                        onClick={lambda -> None { selected = n; }}
                                    >
                                        <div className="node-type">{n.get("type", "unknown")}</div>
                                        <div className="node-id">{n.get("id", "")}</div>
                                    </div>
                                    for n in nodes
                                ]}
                            </div>}
                        </div>
                    </div>

                    <div className="col">
                        {selected
                        and <div className="card">
                            <div className="card-title">Node Detail</div>
                            <p><strong>Type:</strong> {selected.get("type", "")}</p>
                            <p><strong>ID:</strong> <span className="mono">{selected.get("id", "")}</span></p>
                            <div style={{"marginTop": "12px"}}>
                                <strong>Properties:</strong>
                                <div className="code-output" style={{"marginTop": "8px"}}>
                                    {JSON.stringify(selected.get("props", {}), None, 2)}
                                </div>
                            </div>
                        </div>
                        or <div className="card">
                            <div className="empty">Click a node to inspect</div>
                        </div>}

                        <div className="card">
                            <div className="card-title">Edges ({len(edges)})</div>
                            {len(edges) == 0
                            and <div className="empty">No edges</div>
                            or <table>
                                <thead><tr><th>From</th><th>To</th><th>Type</th></tr></thead>
                                <tbody>
                                    {[
                                        <tr key={e.get("from", "") + e.get("to", "")}>
                                            <td className="mono">{e.get("from", "")}</td>
                                            <td className="mono">{e.get("to", "")}</td>
                                            <td>{e.get("type", "")}</td>
                                        </tr>
                                        for e in edges
                                    ]}
                                </tbody>
                            </table>}
                        </div>
                    </div>
                </div>
            </div>;
    }
}
