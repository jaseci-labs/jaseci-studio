/* Jaseci Studio — Developer Workbench Client */
(function () {
  "use strict";

  const API = "/_studio/api";
  let currentTab = "dashboard";
  let tierInfo = { tier: "free", has_pro: false, has_enterprise: false };

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  async function api(path, opts = {}) {
    const url = API + path;
    const res = await fetch(url, {
      headers: { "Content-Type": "application/json", ...(opts.headers || {}) },
      ...opts,
    });
    if (!res.ok) {
      const err = await res.json().catch(() => ({ detail: res.statusText }));
      throw new Error(err.detail || res.statusText);
    }
    return res.json();
  }

  function $(sel) { return document.querySelector(sel); }
  function html(el, h) { el.innerHTML = h; }

  function toast(msg, type = "success") {
    const t = $("#toast");
    t.textContent = msg;
    t.className = "toast show toast-" + type;
    setTimeout(() => (t.className = "toast"), 3000);
  }

  function badge(status) {
    const cls = { success: "badge-success", error: "badge-error", pending: "badge-pending", timeout: "badge-timeout" };
    return `<span class="badge ${cls[status] || ""}">${status}</span>`;
  }

  function tierBadge(tier) {
    return `<span class="tier-badge tier-${tier}">${tier}</span>`;
  }

  // -----------------------------------------------------------------------
  // Navigation
  // -----------------------------------------------------------------------

  const tabs = [
    { id: "dashboard", label: "Dashboard", icon: "\u25A3", subtitle: "Overview of your Jac application" },
    { id: "workbench", label: "Workbench", icon: "\u2692", subtitle: "Test and debug walkers" },
    { id: "graph", label: "Graph Explorer", icon: "\u25CE", subtitle: "Visualize your application graph" },
    { id: "gateway", label: "AI Gateway", icon: "\u2726", subtitle: "Model configuration and cost tracking" },
    { id: "scheduler", label: "Scheduler", icon: "\u23F0", subtitle: "Cron jobs and webhook triggers" },
    { id: "sandbox", label: "Sandbox", icon: "\u25B6", subtitle: "Execute Jac code interactively" },
  ];

  function initNav() {
    const nav = $("#nav");
    html(nav, tabs.map(t =>
      `<button data-tab="${t.id}" class="${t.id === currentTab ? "active" : ""}">
        <span class="icon">${t.icon}</span>${t.label}
      </button>`
    ).join(""));
    nav.querySelectorAll("button").forEach(btn => {
      btn.onclick = () => switchTab(btn.dataset.tab);
    });
  }

  function switchTab(tabId) {
    currentTab = tabId;
    const tab = tabs.find(t => t.id === tabId);
    $("#page-title").textContent = tab.label;
    $("#page-subtitle").textContent = tab.subtitle;
    document.querySelectorAll("#nav button").forEach(b => {
      b.classList.toggle("active", b.dataset.tab === tabId);
    });
    render();
  }

  // -----------------------------------------------------------------------
  // Renderers
  // -----------------------------------------------------------------------

  async function render() {
    const c = $("#content");
    html(c, '<div class="empty"><span class="spinner"></span> Loading...</div>');
    try {
      switch (currentTab) {
        case "dashboard": await renderDashboard(c); break;
        case "workbench": await renderWorkbench(c); break;
        case "graph": await renderGraph(c); break;
        case "gateway": await renderGateway(c); break;
        case "scheduler": await renderScheduler(c); break;
        case "sandbox": await renderSandbox(c); break;
      }
    } catch (e) {
      html(c, `<div class="card"><div class="card-title">Error</div><p>${e.message}</p></div>`);
    }
  }

  // -- Dashboard --
  async function renderDashboard(c) {
    const d = await api("/dashboard");
    html(c, `
      <div class="stats-grid">
        <div class="stat-card">
          <div class="stat-value stat-accent">${d.total_runs}</div>
          <div class="stat-label">Total Walker Runs</div>
        </div>
        <div class="stat-card">
          <div class="stat-value stat-success">${d.success_runs}</div>
          <div class="stat-label">Successful</div>
        </div>
        <div class="stat-card">
          <div class="stat-value stat-error">${d.error_runs}</div>
          <div class="stat-label">Errors</div>
        </div>
        <div class="stat-card">
          <div class="stat-value stat-accent">${d.model_count}</div>
          <div class="stat-label">AI Models</div>
        </div>
        <div class="stat-card">
          <div class="stat-value">$${d.total_cost_usd.toFixed(4)}</div>
          <div class="stat-label">Total LLM Cost</div>
        </div>
        <div class="stat-card">
          <div class="stat-value">${d.schedule_count}</div>
          <div class="stat-label">Active Schedules</div>
        </div>
      </div>
      <div class="row">
        <div class="col">
          <div class="card">
            <div class="card-title">Recent Runs</div>
            <div id="dash-runs"></div>
          </div>
        </div>
        <div class="col">
          <div class="card">
            <div class="card-title">System Health</div>
            <div id="dash-health"></div>
          </div>
        </div>
      </div>
    `);
    // Load recent runs
    try {
      const h = await api("/walkers/history?limit=5");
      const el = document.getElementById("dash-runs");
      if (!h.runs.length) { el.innerHTML = '<div class="empty">No runs yet</div>'; return; }
      el.innerHTML = `<table><thead><tr><th>Walker</th><th>Status</th><th>Time</th></tr></thead><tbody>
        ${h.runs.map(r => `<tr><td>${r.walker_name}</td><td>${badge(r.status)}</td><td>${r.duration_ms}ms</td></tr>`).join("")}
      </tbody></table>`;
    } catch (_) {}
    // Load health
    try {
      const health = await api("/health");
      document.getElementById("dash-health").innerHTML = `
        <p>Status: ${badge(health.status === "healthy" ? "success" : "error").replace(/>.*</, ">" + health.status + "<")}</p>
        <p style="margin-top:8px;font-size:12px;color:var(--text-dim)">Python: ${health.python_version.split(" ")[0]}<br>PID: ${health.pid}</p>
      `;
    } catch (_) {}
  }

  // -- Workbench --
  async function renderWorkbench(c) {
    const [walkerRes, histRes] = await Promise.all([
      api("/walkers"),
      api("/walkers/history?limit=20"),
    ]);
    html(c, `
      <div class="row">
        <div class="col">
          <div class="card">
            <div class="card-title">Run Walker</div>
            <div class="form-group">
              <label>Walker Name</label>
              <select id="wb-walker">
                <option value="">-- select --</option>
                ${walkerRes.walkers.map(w => `<option value="${w.name}">${w.name}</option>`).join("")}
              </select>
            </div>
            <div class="form-group">
              <label>Payload (JSON)</label>
              <textarea id="wb-payload" rows="4">{}</textarea>
            </div>
            <div class="btn-group">
              <button class="btn btn-primary" id="wb-run-btn">Run Walker</button>
            </div>
            <div id="wb-result" style="margin-top:12px"></div>
          </div>
        </div>
        <div class="col">
          <div class="card">
            <div class="card-title">Available Walkers (${walkerRes.walkers.length})</div>
            ${walkerRes.walkers.length === 0 ? '<div class="empty">No walkers found. Start a Jac app first.</div>' :
              `<table><thead><tr><th>Name</th><th>Module</th></tr></thead><tbody>
                ${walkerRes.walkers.map(w => `<tr><td>${w.name}</td><td style="color:var(--text-dim);font-size:11px">${w.module}</td></tr>`).join("")}
              </tbody></table>`}
          </div>
        </div>
      </div>
      <div class="card">
        <div class="card-title">Run History</div>
        ${histRes.runs.length === 0 ? '<div class="empty">No runs recorded yet</div>' :
          `<table><thead><tr><th>Walker</th><th>Status</th><th>Duration</th><th>Time</th><th>Result</th></tr></thead><tbody>
            ${histRes.runs.map(r => `<tr>
              <td>${r.walker_name}</td>
              <td>${badge(r.status)}</td>
              <td>${r.duration_ms}ms</td>
              <td style="font-size:11px;color:var(--text-dim)">${r.started_at || "-"}</td>
              <td style="font-size:11px;max-width:200px;overflow:hidden;text-overflow:ellipsis">${JSON.stringify(r.result).slice(0, 80)}</td>
            </tr>`).join("")}
          </tbody></table>`}
      </div>
    `);
    document.getElementById("wb-run-btn").onclick = async () => {
      const name = document.getElementById("wb-walker").value;
      if (!name) { toast("Select a walker", "error"); return; }
      let payload = {};
      try { payload = JSON.parse(document.getElementById("wb-payload").value); } catch (e) { toast("Invalid JSON payload", "error"); return; }
      const btn = document.getElementById("wb-run-btn");
      btn.disabled = true; btn.textContent = "Running...";
      try {
        const res = await api("/walkers/run", { method: "POST", body: JSON.stringify({ walker_name: name, payload }) });
        document.getElementById("wb-result").innerHTML = `<div class="code-output">${JSON.stringify(res, null, 2)}</div>`;
        toast("Walker executed");
        setTimeout(() => renderWorkbench(c), 500);
      } catch (e) { toast(e.message, "error"); }
      btn.disabled = false; btn.textContent = "Run Walker";
    };
  }

  // -- Graph Explorer --
  async function renderGraph(c) {
    html(c, `
      <div class="card">
        <div class="card-title">Graph Visualization</div>
        <div class="form-group" style="max-width:200px;display:inline-block;margin-right:12px">
          <label>Max Depth</label>
          <input type="number" id="graph-depth" value="5" min="1" max="20">
        </div>
        <button class="btn btn-primary btn-sm" id="graph-refresh">Refresh</button>
        <div id="graph-canvas" style="margin-top:12px"></div>
      </div>
      <div class="card">
        <div class="card-title">Node List</div>
        <div id="graph-table"></div>
      </div>
    `);
    async function loadGraph() {
      const depth = parseInt(document.getElementById("graph-depth").value) || 5;
      const data = await api("/graph?max_depth=" + depth);
      const canvas = document.getElementById("graph-canvas");
      const table = document.getElementById("graph-table");
      if (!data.nodes.length) {
        canvas.innerHTML = '<div class="empty">No graph data</div>';
        table.innerHTML = "";
        return;
      }
      // Simple force-layout positioning
      const w = canvas.clientWidth, h = canvas.clientHeight;
      const positions = {};
      data.nodes.forEach((n, i) => {
        const angle = (2 * Math.PI * i) / data.nodes.length;
        const r = Math.min(w, h) * 0.35;
        positions[n.id] = {
          x: w / 2 + r * Math.cos(angle) - 40,
          y: h / 2 + r * Math.sin(angle) - 12,
        };
      });
      // Root at center
      if (data.nodes[0]) { positions[data.nodes[0].id] = { x: w / 2 - 30, y: h / 2 - 12 }; }
      // Render SVG lines for edges
      let svg = `<svg style="position:absolute;top:0;left:0;width:100%;height:100%;z-index:1">`;
      data.edges.forEach(e => {
        const s = positions[e.source], t = positions[e.target];
        if (s && t) {
          svg += `<line x1="${s.x + 40}" y1="${s.y + 12}" x2="${t.x + 40}" y2="${t.y + 12}" stroke="#2e3247" stroke-width="1.5"/>`;
        }
      });
      svg += `</svg>`;
      let nodesHtml = data.nodes.map(n => {
        const p = positions[n.id];
        return `<div class="graph-node type-${n.type}" style="left:${p.x}px;top:${p.y}px" title="${JSON.stringify(n.props).slice(0, 200)}">${n.type}</div>`;
      }).join("");
      canvas.innerHTML = svg + nodesHtml;
      // Table
      table.innerHTML = `<table><thead><tr><th>Type</th><th>ID</th><th>Properties</th></tr></thead><tbody>
        ${data.nodes.map(n => `<tr><td>${n.type}</td><td style="font-family:var(--mono);font-size:11px">${n.id}</td><td style="font-size:11px;color:var(--text-dim)">${JSON.stringify(n.props).slice(0, 120)}</td></tr>`).join("")}
      </tbody></table>`;
    }
    document.getElementById("graph-refresh").onclick = loadGraph;
    loadGraph();
  }

  // -- AI Gateway --
  async function renderGateway(c) {
    const modelsRes = await api("/models");
    html(c, `
      <div class="row">
        <div class="col">
          <div class="card">
            <div class="card-title">Add Model</div>
            <div class="form-group"><label>Model ID</label><input id="gw-id" placeholder="gpt-4o"></div>
            <div class="form-group"><label>Provider</label><input id="gw-provider" placeholder="openai"></div>
            <div class="form-group"><label>API Key Env Var</label><input id="gw-key" placeholder="OPENAI_API_KEY"></div>
            <div class="form-group"><label>Max Tokens</label><input id="gw-tokens" type="number" value="4096"></div>
            <div class="form-group"><label>Temperature</label><input id="gw-temp" type="number" step="0.1" value="0.7"></div>
            <div class="btn-group">
              <button class="btn btn-primary" id="gw-add">Add Model</button>
            </div>
          </div>
        </div>
        <div class="col">
          <div class="card">
            <div class="card-title">Configured Models (${modelsRes.models.length})</div>
            ${modelsRes.models.length === 0 ? '<div class="empty">No models configured</div>' :
              `<table><thead><tr><th>Model</th><th>Provider</th><th>Max Tokens</th><th></th></tr></thead><tbody>
                ${modelsRes.models.map(m => `<tr>
                  <td>${m.model_id}${m.is_default ? ' <span class="badge badge-success">default</span>' : ""}</td>
                  <td>${m.provider}</td>
                  <td>${m.max_tokens}</td>
                  <td><button class="btn btn-danger btn-sm" onclick="window._studioDeleteModel('${m.model_id}')">Delete</button></td>
                </tr>`).join("")}
              </tbody></table>`}
          </div>
          <div class="card">
            <div class="card-title">Cost Summary</div>
            <div id="gw-costs"><div class="empty">Loading...</div></div>
          </div>
        </div>
      </div>
    `);
    document.getElementById("gw-add").onclick = async () => {
      try {
        await api("/models", { method: "POST", body: JSON.stringify({
          model_id: document.getElementById("gw-id").value,
          provider: document.getElementById("gw-provider").value,
          api_key_env: document.getElementById("gw-key").value,
          max_tokens: parseInt(document.getElementById("gw-tokens").value),
          temperature: parseFloat(document.getElementById("gw-temp").value),
        })});
        toast("Model added");
        renderGateway(c);
      } catch (e) { toast(e.message, "error"); }
    };
    window._studioDeleteModel = async (mid) => {
      try { await api("/models/" + mid, { method: "DELETE" }); toast("Model deleted"); renderGateway(c); }
      catch (e) { toast(e.message, "error"); }
    };
    // Load costs
    try {
      const costs = await api("/costs");
      const el = document.getElementById("gw-costs");
      if (!costs.costs.length) { el.innerHTML = '<div class="empty">No cost data yet</div>'; return; }
      el.innerHTML = `<table><thead><tr><th>Model</th><th>Requests</th><th>Tokens</th><th>Cost</th></tr></thead><tbody>
        ${costs.costs.map(c => `<tr><td>${c.model_id}</td><td>${c.request_count}</td><td>${c.total_input_tokens + c.total_output_tokens}</td><td>$${c.total_cost_usd.toFixed(4)}</td></tr>`).join("")}
      </tbody></table>`;
    } catch (e) {
      document.getElementById("gw-costs").innerHTML = `<div class="empty" style="color:var(--text-dim)">${e.message}</div>`;
    }
  }

  // -- Scheduler --
  async function renderScheduler(c) {
    const schedRes = await api("/schedules");
    html(c, `
      <div class="row">
        <div class="col">
          <div class="card">
            <div class="card-title">Create Schedule</div>
            <div class="form-group"><label>Name</label><input id="sch-name" placeholder="daily-report"></div>
            <div class="form-group"><label>Walker Name</label><input id="sch-walker" placeholder="GenerateReport"></div>
            <div class="form-group"><label>Cron Expression</label><input id="sch-cron" placeholder="0 9 * * *"></div>
            <div class="form-group"><label>Webhook Path (optional)</label><input id="sch-webhook" placeholder="/hooks/my-trigger"></div>
            <div class="form-group"><label>Payload (JSON)</label><textarea id="sch-payload" rows="3">{}</textarea></div>
            <div class="btn-group"><button class="btn btn-primary" id="sch-create">Create</button></div>
          </div>
        </div>
        <div class="col">
          <div class="card">
            <div class="card-title">Schedules (${schedRes.schedules.length})</div>
            ${schedRes.schedules.length === 0 ? '<div class="empty">No schedules configured</div>' :
              `<table><thead><tr><th>Name</th><th>Walker</th><th>Cron</th><th>Enabled</th><th></th></tr></thead><tbody>
                ${schedRes.schedules.map(s => `<tr>
                  <td>${s.name}</td>
                  <td>${s.walker_name}</td>
                  <td style="font-family:var(--mono);font-size:11px">${s.cron_expr || s.webhook_path || "-"}</td>
                  <td>${s.enabled ? badge("success").replace(">success<", ">on<") : badge("error").replace(">error<", ">off<")}</td>
                  <td>
                    <button class="btn btn-sm" onclick="window._studioToggleSched('${s.name}', ${!s.enabled})">${s.enabled ? "Disable" : "Enable"}</button>
                    <button class="btn btn-danger btn-sm" onclick="window._studioDeleteSched('${s.name}')">Delete</button>
                  </td>
                </tr>`).join("")}
              </tbody></table>`}
          </div>
        </div>
      </div>
    `);
    document.getElementById("sch-create").onclick = async () => {
      let payload = {};
      try { payload = JSON.parse(document.getElementById("sch-payload").value); } catch (_) {}
      try {
        await api("/schedules", { method: "POST", body: JSON.stringify({
          name: document.getElementById("sch-name").value,
          walker_name: document.getElementById("sch-walker").value,
          cron_expr: document.getElementById("sch-cron").value,
          webhook_path: document.getElementById("sch-webhook").value,
          payload,
        })});
        toast("Schedule created");
        renderScheduler(c);
      } catch (e) { toast(e.message, "error"); }
    };
    window._studioToggleSched = async (name, enabled) => {
      try { await api("/schedules/toggle", { method: "PUT", body: JSON.stringify({ name, enabled }) }); renderScheduler(c); }
      catch (e) { toast(e.message, "error"); }
    };
    window._studioDeleteSched = async (name) => {
      try { await api("/schedules/" + name, { method: "DELETE" }); toast("Schedule deleted"); renderScheduler(c); }
      catch (e) { toast(e.message, "error"); }
    };
  }

  // -- Sandbox --
  async function renderSandbox(c) {
    const histRes = await api("/sandbox/history?limit=10");
    html(c, `
      <div class="row">
        <div class="col">
          <div class="card">
            <div class="card-title">Jac Code Editor</div>
            <textarea id="sb-code" rows="12" placeholder='with entry {\n    print("Hello from Jac!");\n}'></textarea>
            <div class="form-group" style="margin-top:8px;max-width:200px">
              <label>Timeout (seconds)</label>
              <input type="number" id="sb-timeout" value="10" min="1" max="30">
            </div>
            <div class="btn-group">
              <button class="btn btn-primary" id="sb-run">Run Code</button>
            </div>
          </div>
          <div class="card">
            <div class="card-title">Output</div>
            <div class="code-output" id="sb-output">-- output will appear here --</div>
          </div>
        </div>
        <div class="col">
          <div class="card">
            <div class="card-title">Recent Sessions</div>
            ${histRes.sessions.length === 0 ? '<div class="empty">No sessions yet</div>' :
              `<table><thead><tr><th>ID</th><th>Status</th><th>Time</th></tr></thead><tbody>
                ${histRes.sessions.map(s => `<tr style="cursor:pointer" onclick="window._studioLoadSession('${s.session_id}')">
                  <td style="font-family:var(--mono);font-size:11px">${s.session_id}</td>
                  <td>${badge(s.status)}</td>
                  <td style="font-size:11px;color:var(--text-dim)">${s.created_at}</td>
                </tr>`).join("")}
              </tbody></table>`}
          </div>
        </div>
      </div>
    `);
    // Store sessions for click-to-load
    window._studioSessions = histRes.sessions;
    window._studioLoadSession = (sid) => {
      const s = window._studioSessions.find(x => x.session_id === sid);
      if (s) {
        document.getElementById("sb-code").value = s.code;
        document.getElementById("sb-output").textContent = s.output;
      }
    };
    document.getElementById("sb-run").onclick = async () => {
      const code = document.getElementById("sb-code").value;
      if (!code.trim()) { toast("Enter some Jac code", "error"); return; }
      const btn = document.getElementById("sb-run");
      btn.disabled = true; btn.textContent = "Running...";
      document.getElementById("sb-output").textContent = "Executing...";
      try {
        const res = await api("/sandbox/run", { method: "POST", body: JSON.stringify({
          code, timeout_sec: parseInt(document.getElementById("sb-timeout").value) || 10,
        })});
        document.getElementById("sb-output").textContent = res.output || "(no output)";
        toast(res.status === "success" ? "Execution complete" : "Execution failed: " + res.status, res.status === "success" ? "success" : "error");
        setTimeout(() => renderSandbox(c), 300);
      } catch (e) { toast(e.message, "error"); document.getElementById("sb-output").textContent = e.message; }
      btn.disabled = false; btn.textContent = "Run Code";
    };
  }

  // -----------------------------------------------------------------------
  // Init
  // -----------------------------------------------------------------------

  async function init() {
    initNav();
    try {
      tierInfo = await api("/tier");
      const el = document.getElementById("tier-info");
      el.innerHTML = "Tier: " + tierBadge(tierInfo.tier);
    } catch (_) {}
    render();
  }

  init();
})();
