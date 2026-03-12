cl import from "@jac/runtime" { Link }

cl {
    sv import from ..main { inspect_graph, init_studio, update_node_props }

    def:pub page -> JsxElement {
        has nodes: list = [],
            edges: list = [],
            tree_items: list = [],
            graph_positions: list = [],
            selected: any = None,
            loading: bool = true,
            view_mode: str = "graph",
            search_query: str = "",
            type_filters: list = [],
            all_types: list = [],
            editing_prop: str = "",
            edit_value: str = "",
            saving: bool = false,
            diff_created: list = [],
            diff_modified: list = [],
            diff_walker: str = "";

        async can with entry {
            try {
                root spawn init_studio();
                result = root spawn inspect_graph();
                if result.reports and len(result.reports) > 0 {
                    data = result.reports[0];
                    got_nodes: list = data["nodes"] or [];
                    got_edges: list = data["edges"] or [];
                    nodes = got_nodes;
                    edges = got_edges;

                    # Collect unique types
                    types_set: list = [];
                    for n in got_nodes {
                        found_type: bool = false;
                        for t in types_set {
                            if t == n["type"] { found_type = true; break; }
                        }
                        if not found_type { types_set.append(n["type"]); }
                    }
                    all_types = types_set;
                    type_filters = types_set;

                    # Build flat tree via BFS
                    root_id: str = "";
                    for n in got_nodes {
                        if n["type"] == "Root" { root_id = n["id"]; }
                    }
                    if root_id {
                        flat: list = [];
                        queue: list = [{"id": root_id, "depth": 0}];
                        for _i in range(1000) {
                            if len(queue) == 0 { break; }
                            cur: dict = queue.pop(0);
                            cur_node: dict = {};
                            for nd in got_nodes {
                                if nd["id"] == cur["id"] { cur_node = nd; }
                            }
                            if cur_node and cur_node["id"] {
                                child_list: list = [];
                                for eg in got_edges {
                                    if eg["from"] == cur_node["id"] {
                                        for nd2 in got_nodes {
                                            if nd2["id"] == eg["to"] { child_list.append(nd2); }
                                        }
                                    }
                                }
                                flat.append({
                                    "node": cur_node,
                                    "depth": cur["depth"],
                                    "child_count": len(child_list)
                                });
                                for ch in child_list {
                                    queue.append({"id": ch["id"], "depth": cur["depth"] + 1});
                                }
                            }
                        }
                        tree_items = flat;
                    }

                    # Force-directed layout computation
                    if len(got_nodes) > 0 {
                        # Initialize positions in a circle
                        positions: list = [];
                        node_count: int = len(got_nodes);
                        for ni in range(node_count) {
                            angle: float = (ni * 6.2832) / node_count;
                            positions.append({
                                "id": got_nodes[ni]["id"],
                                "x": 400.0 + 150.0 * Math.cos(angle),
                                "y": 300.0 + 150.0 * Math.sin(angle),
                                "vx": 0.0,
                                "vy": 0.0
                            });
                        }

                        # Run force simulation iterations
                        for _iter in range(80) {
                            # Reset forces
                            forces: list = [];
                            for pi in range(node_count) {
                                forces.append({"fx": 0.0, "fy": 0.0});
                            }

                            # Repulsive force between all pairs
                            for i in range(node_count) {
                                for j in range(i + 1, node_count) {
                                    dx: float = positions[j]["x"] - positions[i]["x"];
                                    dy: float = positions[j]["y"] - positions[i]["y"];
                                    dist_sq: float = dx * dx + dy * dy;
                                    if dist_sq < 1.0 { dist_sq = 1.0; }
                                    dist: float = Math.sqrt(dist_sq);
                                    repulse: float = 8000.0 / dist_sq;
                                    fx: float = (dx / dist) * repulse;
                                    fy: float = (dy / dist) * repulse;
                                    forces[i]["fx"] = forces[i]["fx"] - fx;
                                    forces[i]["fy"] = forces[i]["fy"] - fy;
                                    forces[j]["fx"] = forces[j]["fx"] + fx;
                                    forces[j]["fy"] = forces[j]["fy"] + fy;
                                }
                            }

                            # Attractive force along edges
                            for eg in got_edges {
                                src_idx: int = -1;
                                tgt_idx: int = -1;
                                for pi in range(node_count) {
                                    if positions[pi]["id"] == eg["from"] { src_idx = pi; }
                                    if positions[pi]["id"] == eg["to"] { tgt_idx = pi; }
                                }
                                if src_idx >= 0 and tgt_idx >= 0 {
                                    dx2: float = positions[tgt_idx]["x"] - positions[src_idx]["x"];
                                    dy2: float = positions[tgt_idx]["y"] - positions[src_idx]["y"];
                                    dist2: float = Math.sqrt(dx2 * dx2 + dy2 * dy2);
                                    if dist2 > 0.1 {
                                        attract: float = (dist2 - 100.0) * 0.05;
                                        ax: float = (dx2 / dist2) * attract;
                                        ay: float = (dy2 / dist2) * attract;
                                        forces[src_idx]["fx"] = forces[src_idx]["fx"] + ax;
                                        forces[src_idx]["fy"] = forces[src_idx]["fy"] + ay;
                                        forces[tgt_idx]["fx"] = forces[tgt_idx]["fx"] - ax;
                                        forces[tgt_idx]["fy"] = forces[tgt_idx]["fy"] - ay;
                                    }
                                }
                            }

                            # Center gravity
                            for pi in range(node_count) {
                                forces[pi]["fx"] = forces[pi]["fx"] + (400.0 - positions[pi]["x"]) * 0.01;
                                forces[pi]["fy"] = forces[pi]["fy"] + (300.0 - positions[pi]["y"]) * 0.01;
                            }

                            # Apply forces with damping
                            damping: float = 0.85;
                            for pi in range(node_count) {
                                positions[pi]["vx"] = (positions[pi]["vx"] + forces[pi]["fx"]) * damping;
                                positions[pi]["vy"] = (positions[pi]["vy"] + forces[pi]["fy"]) * damping;
                                positions[pi]["x"] = positions[pi]["x"] + positions[pi]["vx"];
                                positions[pi]["y"] = positions[pi]["y"] + positions[pi]["vy"];
                            }
                        }

                        graph_positions = positions;
                    }
                }
            } except Exception as e {
                print("Graph error:", e);
            }

            # Read walker path overlay from localStorage
            try {
                raw_diff = localStorage.getItem("studio_graph_diff");
                if raw_diff {
                    diff_data = JSON.parse(raw_diff);
                    diff_created = diff_data["created"] or [];
                    diff_modified = diff_data["modified"] or [];
                    diff_walker = diff_data["walker"] or "";
                }
            } except Exception as e2 {
                print("Diff read error:", e2);
            }

            loading = false;
        }

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

        def node_color(ntype: str) -> str {
            if ntype == "Root" { return "#10b981"; }
            palette: list = ["#6366f1", "#f59e0b", "#3b82f6", "#ef4444", "#8b5cf6", "#ec4899", "#14b8a6", "#f97316"];
            hash_val: int = 0;
            for ch in ntype { hash_val = hash_val + ord(ch); }
            return palette[hash_val % len(palette)];
        }

        def node_icon(ntype: str) -> str {
            if len(ntype) > 0 { return ntype[0]; }
            return "?";
        }

        def toggle_type(t: str) -> None {
            new_filters: list = [];
            was_active: bool = false;
            for tf in type_filters {
                if tf == t { was_active = true; }
                else { new_filters.append(tf); }
            }
            if not was_active { new_filters.append(t); }
            type_filters = new_filters;
        }

        def is_node_visible(n: dict) -> bool {
            # Type filter
            type_ok: bool = false;
            for tf in type_filters {
                if tf == n["type"] { type_ok = true; break; }
            }
            if not type_ok { return false; }
            # Search filter
            if search_query {
                haystack = n["type"] + " " + n["id"] + " " + JSON.stringify(n["props"]);
                if search_query not in haystack { return false; }
            }
            return true;
        }

        def get_node_highlight(node_id: str) -> str {
            for cid in diff_created {
                if cid == node_id { return "created"; }
            }
            for mid in diff_modified {
                if mid == node_id { return "modified"; }
            }
            return "";
        }

        def clear_highlights -> None {
            diff_created = [];
            diff_modified = [];
            diff_walker = "";
            localStorage.removeItem("studio_graph_diff");
        }

        def start_edit(prop_name: str, prop_val: str) -> None {
            editing_prop = prop_name;
            edit_value = prop_val;
        }

        async def save_prop -> None {
            if not selected or not editing_prop { return; }
            saving = true;
            try {
                r = root spawn update_node_props(
                    node_id=selected["id"],
                    updates={editing_prop: edit_value}
                );
                if r.reports and len(r.reports) > 0 {
                    resp = r.reports[0];
                    if resp["changed"] and len(resp["changed"]) > 0 {
                        # Update local state
                        selected["props"][editing_prop] = edit_value;
                    }
                }
            } except Exception as e {
                print("Save error:", e);
            }
            editing_prop = "";
            edit_value = "";
            saving = false;
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
                        <div className="subtitle">Navigate and inspect your application graph from root</div>
                    </div>
                    <div className="page-header-actions">
                        <span className="badge badge-info">{len(nodes)} nodes</span>
                        <span className="badge badge-info" style={{"marginLeft": "6px"}}>{len(edges)} edges</span>
                        <div className="tab-bar" style={{"marginLeft": "12px", "padding": "0"}}>
                            <div
                                className={"tab-item" + (" active" if view_mode == "graph" else "")}
                                onClick={lambda -> None { view_mode = "graph"; }}
                            >
                                Graph
                            </div>
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

                {(len(diff_created) > 0 or len(diff_modified) > 0) and <div className="card" style={{"marginBottom": "16px", "padding": "10px 16px", "display": "flex", "alignItems": "center", "gap": "12px", "background": "var(--bg-secondary)", "border": "1px solid var(--accent)"}}>
                    <span style={{"fontSize": "13px", "color": "var(--text-primary)"}}>
                        {"Walker path: " + diff_walker}
                    </span>
                    {len(diff_created) > 0 and <span className="badge badge-success">{len(diff_created)} created</span>}
                    {len(diff_modified) > 0 and <span className="badge badge-warning" style={{"background": "#f59e0b20", "color": "#f59e0b", "border": "1px solid #f59e0b40"}}>{len(diff_modified)} modified</span>}
                    <button
                        className="btn btn-sm"
                        style={{"marginLeft": "auto", "fontSize": "11px"}}
                        onClick={lambda -> None { clear_highlights(); }}
                    >
                        {"Clear highlights"}
                    </button>
                </div>}

                {len(nodes) == 0 and <div className="card">
                    <div className="empty-state">
                        <div className="empty-icon">{"⬡"}</div>
                        <div className="empty-title">No application graph found</div>
                        <div className="empty-desc">
                            Your app's nodes and edges will appear here once walkers create them.
                            Studio filters out its own internal nodes — only your application graph is shown.
                        </div>
                        <div className="code-output" style={{"textAlign": "left", "maxWidth": "360px", "margin": "16px auto 0", "fontSize": "12px"}}>
                            <div>{"# Create nodes in your walker:"}</div>
                            <div>{"can start with Root entry {"}</div>
                            <div>{'  here ++> MyNode(name="hello");'}</div>
                            <div>{'  report "Node created!";'}</div>
                            <div>{"}"}</div>
                        </div>
                    </div>
                </div>}

                {len(nodes) > 0 and <div>
                    <div className="card" style={{"marginBottom": "16px", "padding": "12px 16px"}}>
                        <div style={{"display": "flex", "alignItems": "center", "gap": "12px", "flexWrap": "wrap"}}>
                            <input
                                value={search_query}
                                onChange={lambda e: any -> None { search_query = e.target.value; }}
                                placeholder="Search nodes by type, id, or property..."
                                style={{"flex": "1", "minWidth": "200px", "fontSize": "12px", "fontFamily": "var(--mono)"}}
                            />
                            {[
                                <div
                                    key={t}
                                    onClick={lambda -> None { toggle_type(t); }}
                                    style={{
                                        "display": "flex",
                                        "alignItems": "center",
                                        "gap": "5px",
                                        "padding": "3px 10px",
                                        "borderRadius": "12px",
                                        "fontSize": "11px",
                                        "fontWeight": "600",
                                        "cursor": "pointer",
                                        "border": "1px solid " + node_color(t),
                                        "background": (node_color(t) + "20"),
                                        "color": node_color(t),
                                        "opacity": ("1" if t in type_filters else "0.3")
                                    }}
                                >
                                    <div style={{"width": "6px", "height": "6px", "borderRadius": "50%", "background": node_color(t)}}></div>
                                    {t}
                                </div>
                                for t in all_types
                            ]}
                        </div>
                    </div>

                    <div className="row">
                        <div className="col-2">
                            {view_mode == "graph" and <div className="card" style={{"padding": "0", "overflow": "hidden"}}>
                                <svg
                                    width="100%"
                                    viewBox="0 0 800 600"
                                    style={{"background": "var(--bg)", "borderRadius": "var(--radius)", "minHeight": "400px"}}
                                >
                                    <defs>
                                        <filter id="glow-green" x="-50%" y="-50%" width="200%" height="200%">
                                            <feGaussianBlur stdDeviation="4" result="blur" />
                                            <feFlood floodColor="#10b981" floodOpacity="0.6" result="color" />
                                            <feComposite in="color" in2="blur" operator="in" result="glow" />
                                            <feMerge>
                                                <feMergeNode in="glow" />
                                                <feMergeNode in="SourceGraphic" />
                                            </feMerge>
                                        </filter>
                                        <filter id="glow-amber" x="-50%" y="-50%" width="200%" height="200%">
                                            <feGaussianBlur stdDeviation="4" result="blur" />
                                            <feFlood floodColor="#f59e0b" floodOpacity="0.6" result="color" />
                                            <feComposite in="color" in2="blur" operator="in" result="glow" />
                                            <feMerge>
                                                <feMergeNode in="glow" />
                                                <feMergeNode in="SourceGraphic" />
                                            </feMerge>
                                        </filter>
                                    </defs>
                                    {[
                                        <line
                                            key={eg["from"] + "-" + eg["to"]}
                                            x1={([p["x"] for p in graph_positions if p["id"] == eg["from"]] or [400])[0]}
                                            y1={([p["y"] for p in graph_positions if p["id"] == eg["from"]] or [300])[0]}
                                            x2={([p["x"] for p in graph_positions if p["id"] == eg["to"]] or [400])[0]}
                                            y2={([p["y"] for p in graph_positions if p["id"] == eg["to"]] or [300])[0]}
                                            stroke="var(--border)"
                                            strokeWidth="1.5"
                                            strokeOpacity="0.5"
                                        />
                                        for eg in edges
                                        if is_node_visible({"type": eg["type"], "id": eg["to"], "props": {}})
                                    ]}
                                    {[
                                        <g
                                            key={n["id"]}
                                            onClick={lambda -> None { selected = n; }}
                                            style={{"cursor": "pointer"}}
                                            filter={get_node_highlight(n["id"]) == "created" and "url(#glow-green)" or (get_node_highlight(n["id"]) == "modified" and "url(#glow-amber)" or "none")}
                                        >
                                            <circle
                                                cx={([p["x"] for p in graph_positions if p["id"] == n["id"]] or [400])[0]}
                                                cy={([p["y"] for p in graph_positions if p["id"] == n["id"]] or [300])[0]}
                                                r={selected and selected["id"] == n["id"] and "22" or (get_node_highlight(n["id"]) and "20" or "18")}
                                                fill={get_node_highlight(n["id"]) == "created" and "#10b98140" or (get_node_highlight(n["id"]) == "modified" and "#f59e0b40" or (node_color(n["type"]) + "30"))}
                                                stroke={get_node_highlight(n["id"]) == "created" and "#10b981" or (get_node_highlight(n["id"]) == "modified" and "#f59e0b" or node_color(n["type"]))}
                                                strokeWidth={selected and selected["id"] == n["id"] and "3" or (get_node_highlight(n["id"]) and "3" or "2")}
                                            />
                                            <text
                                                x={([p["x"] for p in graph_positions if p["id"] == n["id"]] or [400])[0]}
                                                y={([p["y"] for p in graph_positions if p["id"] == n["id"]] or [300])[0]}
                                                textAnchor="middle"
                                                dominantBaseline="central"
                                                fill={node_color(n["type"])}
                                                fontSize="12"
                                                fontWeight="700"
                                            >
                                                {node_icon(n["type"])}
                                            </text>
                                            <text
                                                x={([p["x"] for p in graph_positions if p["id"] == n["id"]] or [400])[0]}
                                                y={([p["y"] for p in graph_positions if p["id"] == n["id"]] or [300])[0] + 30}
                                                textAnchor="middle"
                                                fill="var(--text-secondary)"
                                                fontSize="10"
                                            >
                                                {n["type"]}
                                            </text>
                                        </g>
                                        for n in nodes
                                        if is_node_visible(n)
                                    ]}
                                </svg>
                            </div>}

                            {view_mode == "tree" and <div className="card">
                                <div className="card-header">
                                    <div className="card-title">Graph Tree</div>
                                    <div className="card-badge">{len(nodes)} nodes</div>
                                </div>
                                <div style={{"padding": "8px 0"}}>
                                    {len(tree_items) > 0 and [
                                        <div
                                            key={item["node"]["id"]}
                                            className={"graph-tree-node" + (" selected" if selected and selected["id"] == item["node"]["id"] else "")}
                                            onClick={lambda -> None { selected = item["node"]; }}
                                            style={{
                                                "cursor": "pointer",
                                                "paddingLeft": str(item["depth"] * 24) + "px",
                                                "display": (is_node_visible(item["node"]) and "flex" or "none"),
                                                "borderLeft": get_node_highlight(item["node"]["id"]) == "created" and "3px solid #10b981" or (get_node_highlight(item["node"]["id"]) == "modified" and "3px solid #f59e0b" or "3px solid transparent"),
                                                "background": get_node_highlight(item["node"]["id"]) == "created" and "#10b98110" or (get_node_highlight(item["node"]["id"]) == "modified" and "#f59e0b10" or "transparent")
                                            }}
                                        >
                                            {item["depth"] > 0 and <span style={{
                                                "color": "var(--border)",
                                                "marginRight": "6px",
                                                "fontSize": "12px",
                                                "fontFamily": "monospace"
                                            }}>{"└"}</span>}
                                            <div style={{
                                                "width": "32px",
                                                "height": "32px",
                                                "borderRadius": "8px",
                                                "background": node_color(item["node"]["type"]) + "18",
                                                "border": ("2px solid " + node_color(item["node"]["type"])) if selected and selected["id"] == item["node"]["id"] else ("1px solid " + node_color(item["node"]["type"]) + "40"),
                                                "display": "flex",
                                                "alignItems": "center",
                                                "justifyContent": "center",
                                                "fontSize": "13px",
                                                "fontWeight": "700",
                                                "color": node_color(item["node"]["type"]),
                                                "flexShrink": "0"
                                            }}>
                                                {node_icon(item["node"]["type"])}
                                            </div>
                                            <div style={{"flex": "1", "minWidth": "0"}}>
                                                <div style={{"fontSize": "13px", "fontWeight": "600", "color": "var(--text-primary)"}}>{item["node"]["type"]}</div>
                                                <div style={{"fontSize": "11px", "color": "var(--text-muted)", "fontFamily": "var(--mono)", "overflow": "hidden", "textOverflow": "ellipsis", "whiteSpace": "nowrap"}}>
                                                    {item["node"]["id"]}
                                                </div>
                                            </div>
                                            {item["child_count"] > 0 and <div style={{"fontSize": "11px", "color": "var(--text-muted)", "background": "var(--bg-secondary)", "borderRadius": "10px", "padding": "1px 8px", "flexShrink": "0"}}>
                                                {item["child_count"]}
                                            </div>}
                                        </div>
                                        for item in tree_items
                                    ]}
                                    {len(tree_items) == 0 and <div className="empty">No root node found</div>}
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
                                                style={{"display": (is_node_visible(n) and "block" or "none")}}
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

                                    <div style={{"display": "flex", "gap": "8px", "marginBottom": "16px"}}>
                                        <Link
                                            to={"/workbench?node=" + selected["id"]}
                                            className="btn btn-primary btn-sm"
                                            style={{"fontSize": "12px", "textDecoration": "none"}}
                                        >
                                            {"Spawn Walker Here"}
                                        </Link>
                                        <button
                                            className="btn btn-sm"
                                            style={{"fontSize": "12px"}}
                                            onClick={lambda -> None { navigator.clipboard.writeText(selected["id"]); }}
                                        >
                                            {"Copy ID"}
                                        </button>
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
                                    {selected["props"] and <div style={{"marginBottom": "16px"}}>
                                        {[
                                            <div key={pk} style={{"display": "flex", "alignItems": "center", "gap": "8px", "padding": "6px 0", "borderBottom": "1px solid var(--border)", "fontSize": "12px"}}>
                                                <span style={{"color": "#818cf8", "fontFamily": "var(--mono)", "minWidth": "80px", "flexShrink": "0"}}>{pk}</span>
                                                {editing_prop == pk
                                                and <div style={{"display": "flex", "flex": "1", "gap": "4px"}}>
                                                    <input
                                                        value={edit_value}
                                                        onChange={lambda e: any -> None { edit_value = e.target.value; }}
                                                        style={{"flex": "1", "fontSize": "12px", "fontFamily": "var(--mono)", "padding": "2px 6px"}}
                                                        autoFocus={true}
                                                    />
                                                    <button
                                                        className="btn btn-primary btn-sm"
                                                        style={{"fontSize": "10px", "padding": "2px 8px"}}
                                                        onClick={lambda -> None { save_prop(); }}
                                                        disabled={saving}
                                                    >
                                                        {saving and "..." or "Save"}
                                                    </button>
                                                    <button
                                                        className="btn btn-sm"
                                                        style={{"fontSize": "10px", "padding": "2px 8px"}}
                                                        onClick={lambda -> None { editing_prop = ""; }}
                                                    >
                                                        {"X"}
                                                    </button>
                                                </div>
                                                or <span
                                                    style={{"flex": "1", "color": "var(--text-secondary)", "fontFamily": "var(--mono)", "cursor": "pointer"}}
                                                    onClick={lambda -> None { start_edit(pk, selected["props"][pk]); }}
                                                >
                                                    {selected["props"][pk]}
                                                </span>}
                                            </div>
                                            for pk in Object.keys(selected["props"])
                                        ]}
                                        <div style={{"fontSize": "10px", "color": "var(--text-muted)", "marginTop": "6px"}}>Click a value to edit</div>
                                    </div>}

                                    <div className="section-title">Edges</div>
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
                                    <div className="empty-desc">Click on a node to inspect its properties and connections</div>
                                </div>}
                            </div>
                        </div>
                    </div>
                </div>}
            </div>;
    }
}
