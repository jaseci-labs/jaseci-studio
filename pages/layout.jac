cl import from "@jac/runtime" { Link, Outlet, useLocation }

cl {
    def:pub layout -> JsxElement {
        location = useLocation();
        current = location.pathname;

        return
            <div className="studio-layout">
                <aside className="sidebar">
                    <div className="sidebar-logo">
                        <div className="logo-mark">JS</div>
                        <div>
                            <div className="logo-text">Jaseci Studio</div>
                            <div className="logo-version">v0.1.0</div>
                        </div>
                    </div>
                    <nav className="sidebar-nav">
                        <div className="sidebar-section">Overview</div>
                        <Link to="/" className={"nav-item" + (" active" if current == "/" else "")}>
                            <span className="nav-icon">{"▶"}</span>
                            Dashboard
                        </Link>
                        <div className="sidebar-section">Develop</div>
                        <Link to="/workbench" className={"nav-item" + (" active" if current == "/workbench" else "")}>
                            <span className="nav-icon">{"⚙"}</span>
                            Workbench
                        </Link>
                        <Link to="/graph" className={"nav-item" + (" active" if current == "/graph" else "")}>
                            <span className="nav-icon">{"⬡"}</span>
                            Graph Explorer
                        </Link>
                        <Link to="/sandbox" className={"nav-item" + (" active" if current == "/sandbox" else "")}>
                            <span className="nav-icon">{"⌘"}</span>
                            Sandbox
                        </Link>
                        <div className="sidebar-section">Configure</div>
                        <Link to="/gateway" className={"nav-item" + (" active" if current == "/gateway" else "")}>
                            <span className="nav-icon">{"⬣"}</span>
                            AI Gateway
                        </Link>
                        <Link to="/scheduler" className={"nav-item" + (" active" if current == "/scheduler" else "")}>
                            <span className="nav-icon">{"⏰"}</span>
                            Scheduler
                        </Link>
                    </nav>
                    <div className="sidebar-footer">
                        <div className="status-dot"></div>
                        <span className="footer-text">Server running</span>
                    </div>
                </aside>
                <main className="main-content">
                    <Outlet/>
                </main>
            </div>;
    }
}
