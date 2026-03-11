"""Graph Explorer page — visualize the application graph."""

sv import from ...main { inspect_graph }

def:pub page() -> JsxElement {
    has graph_data: dict = {"nodes": [], "edges": []};
    has max_depth: int = 5;
    has loading: bool = True;
    has selected_node: any = None;

    async can with entry {
        await load_graph();
    }

    async def load_graph() -> None {
        loading = True;
        try {
            result = root spawn inspect_graph(max_depth=max_depth);
            if result.reports and result.reports.length > 0 {
                graph_data = result.reports[0];
            }
        } except Exception as e {
            graph_data = {"nodes": [], "edges": []};
        }
        loading = False;
    }

    return <div className="page">
        <div className="page-header">
            <h1>Graph Explorer</h1>
            <p className="subtitle">Visualize your application graph</p>
        </div>

        <div className="card">
            <div className="card-title">Controls</div>
            <div style={{"display": "flex", "gap": "12px", "alignItems": "flex-end"}}>
                <div className="form-group" style={{"marginBottom": "0", "width": "150px"}}>
                    <label>Max Depth</label>
                    <input
                        type="number"
                        value={max_depth}
                        min={1}
                        max={20}
                        onChange={lambda e: any -> None { max_depth = parseInt(e.target.value) or 5; }}
                    />
                </div>
                <button className="btn btn-primary" onClick={lambda -> None { load_graph(); }}>
                    Refresh
                </button>
            </div>
        </div>

        <div className="card">
            <div className="card-title">
                Graph ({graph_data["nodes"].length} nodes, {graph_data["edges"].length} edges)
            </div>
            {loading and (
                <div className="empty">Loading graph...</div>
            ) or graph_data["nodes"].length == 0 and (
                <div className="empty">No graph data. Bootstrap Studio with init_studio first.</div>
            ) or (
                <div className="graph-grid">
                    {[
                        <div
                            key={n["id"]}
                            className={"graph-node-card" + (n["type"] == "Root" and " root-node" or "")}
                            onClick={lambda -> None { selected_node = n; }}
                        >
                            <div className="node-type">{n["type"]}</div>
                            <div className="node-id">{n["id"].slice(0, 8)}...</div>
                        </div>
                        for n in graph_data["nodes"]
                    ]}
                </div>
            )}
        </div>

        {selected_node and (
            <div className="card">
                <div className="card-title">Node Detail: {selected_node["type"]}</div>
                <div className="code-output">
                    {JSON.stringify(selected_node["props"], None, 2)}
                </div>
                <button
                    className="btn btn-sm"
                    style={{"marginTop": "8px"}}
                    onClick={lambda -> None { selected_node = None; }}
                >
                    Close
                </button>
            </div>
        )}

        <div className="card">
            <div className="card-title">Node List</div>
            <table>
                <thead><tr><th>Type</th><th>ID</th><th>Properties</th></tr></thead>
                <tbody>
                    {[
                        <tr key={n["id"]} onClick={lambda -> None { selected_node = n; }} style={{"cursor": "pointer"}}>
                            <td>{n["type"]}</td>
                            <td className="mono" style={{"fontSize": "11px"}}>{n["id"]}</td>
                            <td className="text-dim" style={{"fontSize": "11px"}}>
                                {JSON.stringify(n["props"]).slice(0, 80)}
                            </td>
                        </tr>
                        for n in graph_data["nodes"]
                    ]}
                </tbody>
            </table>
        </div>
    </div>;
}
