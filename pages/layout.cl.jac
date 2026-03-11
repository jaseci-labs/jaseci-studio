"""Root layout — sidebar navigation with content outlet."""

import from "@jac/runtime" { Link, Outlet, useLocation }
import "../styles/studio.css";

def:pub layout() -> JsxElement {
    location = useLocation();
    current = location.pathname;

    nav_items = [
        {"/": "Dashboard"},
        {"/workbench": "Workbench"},
        {"/graph": "Graph Explorer"},
        {"/gateway": "AI Gateway"},
        {"/scheduler": "Scheduler"},
        {"/sandbox": "Sandbox"}
    ];

    return <div className="studio-layout">
        <aside className="sidebar">
            <div className="sidebar-logo">
                <span className="logo-icon">&#9670;</span>
                Jaseci Studio
            </div>
            <nav className="sidebar-nav">
                {[
                    <Link
                        key={Object.keys(item)[0]}
                        to={Object.keys(item)[0]}
                        className={"nav-item" + (current == Object.keys(item)[0] and " active" or "")}
                    >
                        {Object.values(item)[0]}
                    </Link>
                    for item in nav_items
                ]}
            </nav>
            <div className="sidebar-footer">
                <span className="version">v0.1.0</span>
            </div>
        </aside>
        <main className="main-content">
            <Outlet />
        </main>
    </div>;
}
