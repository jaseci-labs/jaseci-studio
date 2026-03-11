cl import from "@jac/runtime" { Link, Outlet, useLocation }

cl {
    def:pub layout -> JsxElement {
        location = useLocation();
        current = location.pathname;

        return
            <div className="studio-layout">
                <aside className="sidebar">
                    <div className="sidebar-logo">
                        Jaseci Studio
                    </div>
                    <nav className="sidebar-nav">
                        <Link to="/" className={"nav-item" + (" active" if current == "/" else "")}>
                            Dashboard
                        </Link>
                        <Link to="/workbench" className={"nav-item" + (" active" if current == "/workbench" else "")}>
                            Workbench
                        </Link>
                        <Link to="/graph" className={"nav-item" + (" active" if current == "/graph" else "")}>
                            Graph Explorer
                        </Link>
                        <Link to="/gateway" className={"nav-item" + (" active" if current == "/gateway" else "")}>
                            AI Gateway
                        </Link>
                        <Link to="/scheduler" className={"nav-item" + (" active" if current == "/scheduler" else "")}>
                            Scheduler
                        </Link>
                        <Link to="/sandbox" className={"nav-item" + (" active" if current == "/sandbox" else "")}>
                            Sandbox
                        </Link>
                    </nav>
                    <div className="sidebar-footer">
                        v0.1.0
                    </div>
                </aside>
                <main className="main-content">
                    <Outlet/>
                </main>
            </div>;
    }
}
