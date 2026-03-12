cl {
    def:pub page -> JsxElement {
        return
            <div className="page">
                <div className="page-header">
                    <div className="page-header-left">
                        <h1>Jac Playground</h1>
                        <div className="subtitle">Write and experiment with Jac code in the browser</div>
                    </div>
                </div>

                <div className="card">
                    <div style={{"padding": "8px 0"}}>
                        <div style={{"fontSize": "16px", "fontWeight": "700", "marginBottom": "8px"}}>Use the Jac Playground</div>
                        <div style={{"fontSize": "14px", "color": "var(--text-secondary)", "lineHeight": "1.6", "marginBottom": "20px"}}>
                            The Jac ecosystem has dedicated tools for writing and experimenting with code.
                            Studio focuses on runtime inspection — testing walkers, exploring your graph, and debugging your running app.
                        </div>

                        <a
                            href="https://jac-builder.jaseci.org/"
                            target="_blank"
                            className="quick-action"
                            style={{"textDecoration": "none", "maxWidth": "480px"}}
                        >
                            <span className="qa-icon">{"<>"}</span>
                            <div className="qa-text">
                                <div className="qa-title">Open JacBuilder</div>
                                <div className="qa-desc">Full-featured web IDE with file management, live preview, AI assistance, and deployment</div>
                            </div>
                        </a>
                    </div>
                </div>

                <div className="card" style={{"marginTop": "16px"}}>
                    <div className="card-header">
                        <div className="card-title">What Studio Does Instead</div>
                    </div>
                    <div style={{"display": "grid", "gridTemplateColumns": "1fr 1fr 1fr", "gap": "12px"}}>
                        <div style={{"background": "var(--bg-secondary)", "borderRadius": "var(--radius)", "padding": "16px"}}>
                            <div style={{"fontWeight": "600", "marginBottom": "6px"}}>Walker Workbench</div>
                            <div style={{"fontSize": "13px", "color": "var(--text-secondary)", "lineHeight": "1.5"}}>
                                Discover walkers from your running app, test them with typed form inputs, see graph changes after each run
                            </div>
                        </div>
                        <div style={{"background": "var(--bg-secondary)", "borderRadius": "var(--radius)", "padding": "16px"}}>
                            <div style={{"fontWeight": "600", "marginBottom": "6px"}}>Graph Explorer</div>
                            <div style={{"fontSize": "13px", "color": "var(--text-secondary)", "lineHeight": "1.5"}}>
                                Navigate your application graph, inspect node properties, spawn walkers on any node
                            </div>
                        </div>
                        <div style={{"background": "var(--bg-secondary)", "borderRadius": "var(--radius)", "padding": "16px"}}>
                            <div style={{"fontWeight": "600", "marginBottom": "6px"}}>Runtime Debugging</div>
                            <div style={{"fontSize": "13px", "color": "var(--text-secondary)", "lineHeight": "1.5"}}>
                                See what a walker changed in the graph — new nodes, modified properties, before/after diffs
                            </div>
                        </div>
                    </div>
                </div>
            </div>;
    }
}
