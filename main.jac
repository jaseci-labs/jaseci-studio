"""Jaseci Studio — Developer Workbench for Jac Applications."""

include models;
include walkers;

cl {
    def:pub app() -> JsxElement {
        return <div>
            <h1>Jaseci Studio</h1>
            <p>Developer workbench for Jac applications.</p>
        </div>;
    }
}
