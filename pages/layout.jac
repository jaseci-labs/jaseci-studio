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
                        <Link to="/logs" className={"nav-item" + (" active" if current == "/logs" else "")}>
                            <span className="nav-icon">{"|"}</span>
                            Logs
                        </Link>
                        <div className="sidebar-section">Resources</div>
                        <Link to="/packages" className={"nav-item" + (" active" if current == "/packages" else "")}>
                            <span className="nav-icon">{"📦"}</span>
                            Packages
                        </Link>
                        <Link to="/sandbox" className={"nav-item" + (" active" if current == "/sandbox" else "")}>
                            <span className="nav-icon">{"⌘"}</span>
                            Playground
                        </Link>
                        <Link to="/gateway" className={"nav-item" + (" active" if current == "/gateway" else "")}>
                            <span className="nav-icon">{"⬣"}</span>
                            AI Gateway
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
