cl {
    sv import from ..main { inspect_graph, init_studio }

    def:pub page -> JsxElement {
        has nodes: list = [],
            edges: list = [],
            selected: any = None,
            loading: bool = true,
            view_mode: str = "tree";

        async can with entry {
            try {
                # Ensure studio graph is bootstrapped
                root spawn init_studio();
                result = root spawn inspect_graph();
                if result.reports and len(result.reports) > 0 {
                    data = result.reports[0];
                    nodes = data["nodes"] or [];
                    edges = data["edges"] or [];
                }
            } except Exception as e {
                print("Graph error:", e);
            }
            loading = false;
        }

        # Build adjacency: parent_id -> list of child nodes
        def get_children(parent_id: str) -> list {
            children: list = [];
            for e in edges {
                if e["from"] == parent_id {
                    for n in nodes {
                        if n["id"] == e["to"] {
                            children.append(n);
                            break;
                        }
                    }
                }
            }
            return children;
        }

        def get_edge_type(from_id: str, to_id: str) -> str {
            for e in edges {
                if e["from"] == from_id and e["to"] == to_id {
                    return e["type"];
                }
            }
            return "";
        }

        # Color mapping for node types
        def node_color(ntype: str) -> str {
            if ntype == "Root" { return "#10b981"; }
            if ntype == "StudioRoot" { return "#6366f1"; }
            if ntype == "WalkerRun" { return "#f59e0b"; }
            if ntype == "ModelConfig" { return "#3b82f6"; }
            if ntype == "CostRecord" { return "#ef4444"; }
            if ntype == "Schedule" { return "#8b5cf6"; }
            if ntype == "SandboxSession" { return "#ec4899"; }
            return "#6b7280";
        }

        def node_icon(ntype: str) -> str {
            if ntype == "Root" { return "R"; }
            if ntype == "StudioRoot" { return "S"; }
            if ntype == "WalkerRun" { return "W"; }
            if ntype == "ModelConfig" { return "M"; }
            if ntype == "CostRecord" { return "$"; }
            if ntype == "Schedule" { return "T"; }
            if ntype == "SandboxSession" { return "C"; }
            return "?";
        }

        # Render a tree node and its children recursively as JSX
        def render_tree_node(n: any, depth: int) -> JsxElement {
            children = get_children(n["id"]);
            is_selected = selected and selected["id"] == n["id"];
            color = node_color(n["type"]);

            return
                <div key={n["id"]} style={{"marginLeft": (str(depth * 28) + "px") if depth > 0 else "0"}}>
                    <div
                        className={"graph-tree-node" + (" selected" if is_selected else "")}
                        onClick={lambda -> None { selected = n; }}
                        style={{"cursor": "pointer"}}
                    >
                        {depth > 0 and <div className="tree-connector">
                            <svg width="20" height="24" style={{"flexShrink": "0"}}>
                                <path d="M0 0 L0 12 L20 12" stroke="var(--border)" strokeWidth="1.5" fill="none"/>
                            </svg>
                        </div>}
                        <div style={{
                            "width": "32px",
                            "height": "32px",
                            "borderRadius": "8px",
                            "background": color + "18",
                            "border": ("2px solid " + color) if is_selected else ("1px solid " + color + "40"),
                            "display": "flex",
                            "alignItems": "center",
                            "justifyContent": "center",
                            "fontSize": "13px",
                            "fontWeight": "700",
                            "color": color,
                            "flexShrink": "0"
                        }}>
                            {node_icon(n["type"])}
                        </div>
                        <div style={{"flex": "1", "minWidth": "0"}}>
                            <div style={{"fontSize": "13px", "fontWeight": "600", "color": "var(--text-primary)"}}>{n["type"]}</div>
                            <div style={{"fontSize": "11px", "color": "var(--text-muted)", "fontFamily": "var(--mono)", "overflow": "hidden", "textOverflow": "ellipsis", "whiteSpace": "nowrap"}}>
                                {n["id"]}
                            </div>
                        </div>
                        {len(children) > 0 and <div style={{"fontSize": "11px", "color": "var(--text-muted)", "background": "var(--bg-secondary)", "borderRadius": "10px", "padding": "1px 8px", "flexShrink": "0"}}>
                            {len(children)}
                        </div>}
                    </div>
                    {[render_tree_node(c, depth + 1) for c in children]}
                </div>;
        }

        # Find root node
        def find_root -> any {
            for n in nodes {
                if n["type"] == "Root" {
                    return n;
                }
            }
            return None;
        }

        if loading {
            return
                <div className="page-loading">
                    <div className="spinner"></div>
                    <div className="loading-text">Loading graph...</div>
                </div>;
        }

        root_node = find_root();

        return
            <div className="page">
                <div className="page-header">
                    <div className="page-header-left">
                        <h1>Graph Explorer</h1>
                        <div className="subtitle">Navigate and inspect your application graph from root</div>
                    </div>
                    <div className="page-header-actions">
                        <span className="badge badge-info">{len(nodes)} nodes</span>
                        <span className="badge badge-info" style={{"marginLeft": "6px"}}>{len(edges)} edges</span>
                        <div className="tab-bar" style={{"marginLeft": "12px", "padding": "0"}}>
                            <div
                                className={"tab-item" + (" active" if view_mode == "tree" else "")}
                                onClick={lambda -> None { view_mode = "tree"; }}
                            >
                                Tree
                            </div>
                            <div
                                className={"tab-item" + (" active" if view_mode == "table" else "")}
                                onClick={lambda -> None { view_mode = "table"; }}
                            >
                                Table
                            </div>
                        </div>
                    </div>
                </div>

                {len(nodes) == 0 and <div className="card">
                    <div className="empty-state">
                        <div className="empty-icon">{"⬡"}</div>
                        <div className="empty-title">Graph is empty</div>
                        <div className="empty-desc">Run init_studio from the Workbench to bootstrap the Studio graph, then come back here to explore it.</div>
                    </div>
                </div>}

                {len(nodes) > 0 and <div className="row">
                    <div className="col-2">
                        {view_mode == "tree" and <div className="card">
                            <div className="card-header">
                                <div className="card-title">Graph Tree</div>
                                <div className="card-badge">{len(nodes)} nodes</div>
                            </div>
                            <div style={{"padding": "8px 0"}}>
                                {root_node and render_tree_node(root_node, 0)}
                                {not root_node and <div className="empty">No root node found</div>}
                            </div>
                        </div>}

                        {view_mode == "table" and <div>
                            <div className="card">
                                <div className="card-header">
                                    <div className="card-title">Nodes</div>
                                    <div className="card-badge">{len(nodes)}</div>
                                </div>
                                <div className="graph-grid">
                                    {[
                                        <div
                                            key={n["id"]}
                                            className={"graph-node-card" + (" root-node" if n["type"] == "Root" else "") + (" selected" if selected and selected["id"] == n["id"] else "")}
                                            onClick={lambda -> None { selected = n; }}
                                        >
                                            <div className="node-type">{n["type"]}</div>
                                            <div className="node-id">{n["id"]}</div>
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
                                            <tr key={e["from"] + e["to"]}>
                                                <td className="mono truncate" style={{"maxWidth": "120px"}}>{e["from"]}</td>
                                                <td style={{"color": "var(--text-muted)", "textAlign": "center"}}>{">"}</td>
                                                <td className="mono truncate" style={{"maxWidth": "120px"}}>{e["to"]}</td>
                                                <td><span className="badge badge-info">{e["type"]}</span></td>
                                            </tr>
                                            for e in edges
                                        ]}
                                    </tbody>
                                </table>}
                            </div>
                        </div>}
                    </div>

                    <div className="col">
                        <div className="card" style={{"position": "sticky", "top": "28px"}}>
                            <div className="card-header">
                                <div className="card-title">Inspector</div>
                            </div>
                            {selected
                            and <div>
                                <div style={{"display": "flex", "alignItems": "center", "gap": "10px", "marginBottom": "16px"}}>
                                    <div style={{
                                        "width": "40px",
                                        "height": "40px",
                                        "borderRadius": "10px",
                                        "background": node_color(selected["type"]) + "18",
                                        "border": "2px solid " + node_color(selected["type"]),
                                        "display": "flex",
                                        "alignItems": "center",
                                        "justifyContent": "center",
                                        "fontSize": "16px",
                                        "fontWeight": "700",
                                        "color": node_color(selected["type"])
                                    }}>
                                        {node_icon(selected["type"])}
                                    </div>
                                    <div>
                                        <div style={{"fontWeight": "600", "fontSize": "16px"}}>{selected["type"]}</div>
                                        <div className="mono" style={{"fontSize": "11px", "color": "var(--text-muted)"}}>{selected["id"]}</div>
                                    </div>
                                </div>

                                <div className="section-title">Children</div>
                                <div style={{"marginBottom": "16px"}}>
                                    {len(get_children(selected["id"])) == 0
                                    and <div style={{"fontSize": "13px", "color": "var(--text-muted)", "padding": "8px 0"}}>No children (leaf node)</div>
                                    or <div style={{"display": "flex", "flexWrap": "wrap", "gap": "6px"}}>
                                        {[
                                            <div
                                                key={c["id"]}
                                                onClick={lambda -> None { selected = c; }}
                                                style={{
                                                    "display": "flex",
                                                    "alignItems": "center",
                                                    "gap": "6px",
                                                    "padding": "4px 10px",
                                                    "borderRadius": "var(--radius)",
                                                    "background": "var(--bg-secondary)",
                                                    "cursor": "pointer",
                                                    "fontSize": "12px",
                                                    "border": "1px solid var(--border)"
                                                }}
                                            >
                                                <div style={{
                                                    "width": "8px",
                                                    "height": "8px",
                                                    "borderRadius": "50%",
                                                    "background": node_color(c["type"])
                                                }}></div>
                                                {c["type"]}
                                                <span style={{"color": "var(--text-muted)"}}>{">"}</span>
                                            </div>
                                            for c in get_children(selected["id"])
                                        ]}
                                    </div>}
                                </div>

                                <div className="section-title">Properties</div>
                                <div className="code-output">
                                    {JSON.stringify(selected["props"], None, 2)}
                                </div>

                                <div className="section-title" style={{"marginTop": "16px"}}>Edges</div>
                                <div>
                                    {[
                                        <div key={e["from"] + e["to"]} style={{"display": "flex", "alignItems": "center", "gap": "8px", "padding": "4px 0", "fontSize": "12px"}}>
                                            <span className="mono" style={{"color": "var(--text-muted)"}}>{e["from"]}</span>
                                            <span style={{"color": "var(--accent)"}}>{">"}</span>
                                            <span className="mono" style={{"color": "var(--text-muted)"}}>{e["to"]}</span>
                                            <span className="badge badge-info" style={{"fontSize": "10px"}}>{e["type"]}</span>
                                        </div>
                                        for e in edges
                                        if e["from"] == selected["id"] or e["to"] == selected["id"]
                                    ]}
                                </div>
                            </div>
                            or <div className="empty-state">
                                <div className="empty-icon">{"⬡"}</div>
                                <div className="empty-title">No node selected</div>
                                <div className="empty-desc">Click on a node in the tree to inspect its properties and connections</div>
                            </div>}
                        </div>

                        <div className="card" style={{"position": "sticky", "top": "500px"}}>
                            <div className="card-header">
                                <div className="card-title">Legend</div>
                            </div>
                            <div style={{"display": "flex", "flexWrap": "wrap", "gap": "8px"}}>
                                {[
                                    <div key={t} style={{"display": "flex", "alignItems": "center", "gap": "6px", "fontSize": "12px"}}>
                                        <div style={{"width": "12px", "height": "12px", "borderRadius": "3px", "background": node_color(t)}}></div>
                                        {t}
                                    </div>
                                    for t in ["Root", "StudioRoot", "WalkerRun", "ModelConfig", "CostRecord", "Schedule", "SandboxSession"]
                                ]}
                            </div>
                        </div>
                    </div>
                </div>}
            </div>;
    }
}
