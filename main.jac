"""Jaseci Studio — Developer Workbench for Jac Applications."""

include models;
include walkers;

cl import "./styles/studio.css";

cl {
    def:pub app(children: any = None) -> JsxElement {
        return
            <div>
                {children}
            </div>;
    }
}
