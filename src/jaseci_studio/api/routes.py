"""Studio API routes — thin Python layer that spawns Jac walkers."""

from __future__ import annotations

import logging
import subprocess
import tempfile
import os
import time
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from jaseci_studio.utils.licensing import get_license_tier, has_tier

logger = logging.getLogger(__name__)

studio_router = APIRouter(prefix="/_studio/api", tags=["studio"])

# ---------------------------------------------------------------------------
# Request / response models
# ---------------------------------------------------------------------------


class RunWalkerReq(BaseModel):
    walker_name: str
    payload: dict = {}


class ModelConfigReq(BaseModel):
    model_id: str
    provider: str = ""
    api_key_env: str = ""
    is_default: bool = False
    max_tokens: int = 4096
    temperature: float = 0.7


class ScheduleReq(BaseModel):
    name: str
    walker_name: str = ""
    payload: dict = {}
    cron_expr: str = ""
    webhook_path: str = ""


class ToggleReq(BaseModel):
    name: str
    enabled: bool = True


class SandboxReq(BaseModel):
    code: str
    timeout_sec: int = Field(default=10, le=30)


# ---------------------------------------------------------------------------
# In-memory store (graph persistence delegated to Jac runtime when available)
# ---------------------------------------------------------------------------

_store: dict[str, list] = {
    "runs": [],
    "models": [],
    "costs": [],
    "schedules": [],
    "sandbox": [],
}


# ---------------------------------------------------------------------------
# Dashboard
# ---------------------------------------------------------------------------


@studio_router.get("/dashboard")
async def get_dashboard():
    success = sum(1 for r in _store["runs"] if r["status"] == "success")
    errors = sum(1 for r in _store["runs"] if r["status"] == "error")
    total_cost = sum(c.get("cost_usd", 0) for c in _store["costs"])
    return {
        "total_runs": len(_store["runs"]),
        "success_runs": success,
        "error_runs": errors,
        "total_cost_usd": total_cost,
        "model_count": len(_store["models"]),
        "schedule_count": len(_store["schedules"]),
        "tier": get_license_tier(),
    }


@studio_router.get("/health")
async def get_health():
    import sys

    return {
        "status": "healthy",
        "python_version": sys.version,
        "pid": os.getpid(),
        "timestamp": time.time(),
        "tier": get_license_tier(),
    }


# ---------------------------------------------------------------------------
# Workbench — walker testing
# ---------------------------------------------------------------------------


@studio_router.get("/walkers")
async def list_walkers():
    walkers: list[dict] = []
    try:
        from jaclang.runtimelib.architype import WalkerArchitype

        for cls in WalkerArchitype.__subclasses__():
            walkers.append(
                {"name": cls.__name__, "module": getattr(cls, "__module__", "")}
            )
    except ImportError:
        pass
    return {"walkers": walkers}


@studio_router.post("/walkers/run")
async def run_walker(req: RunWalkerReq):
    start = time.time()
    status = "error"
    result: dict = {}

    try:
        from jaclang.runtimelib.architype import WalkerArchitype
        from jaclang import Jac

        walker_cls = None
        for cls in WalkerArchitype.__subclasses__():
            if cls.__name__ == req.walker_name:
                walker_cls = cls
                break

        if walker_cls is None:
            raise ValueError(f"Walker '{req.walker_name}' not found")

        w = walker_cls(**req.payload)
        root = Jac.get_root()
        spawn_result = root.__jac__.spawn_call(w)
        reports = (
            spawn_result.reports if hasattr(spawn_result, "reports") else []
        )
        result = {"reports": reports}
        status = "success"
    except ImportError:
        result = {"error": "jaclang runtime not available"}
    except Exception as e:
        result = {"error": str(e)}

    elapsed = int((time.time() - start) * 1000)
    now = datetime.now(timezone.utc).isoformat()

    record = {
        "walker_name": req.walker_name,
        "payload": req.payload,
        "status": status,
        "result": result,
        "started_at": now,
        "duration_ms": elapsed,
    }
    _store["runs"].append(record)
    return record


@studio_router.get("/walkers/history")
async def get_run_history(limit: int = 20):
    runs = sorted(_store["runs"], key=lambda r: r["started_at"], reverse=True)
    return {"runs": runs[:limit]}


# ---------------------------------------------------------------------------
# Graph inspector
# ---------------------------------------------------------------------------


@studio_router.get("/graph")
async def inspect_graph(max_depth: int = 5):
    nodes: list[dict] = []
    edges: list[dict] = []
    try:
        from jaclang import Jac

        root = Jac.get_root()
        seen: set = set()

        def _walk(node: object, depth: int) -> None:
            nid = str(id(node))
            if nid in seen or depth > max_depth:
                return
            seen.add(nid)
            ntype = type(node).__name__
            nodes.append({"id": nid, "type": ntype, "props": {}})
            try:
                children = node.__jac__.edges
                for edge in children:
                    target = edge.target
                    tid = str(id(target))
                    edges.append(
                        {
                            "source": nid,
                            "target": tid,
                            "type": type(edge).__name__,
                        }
                    )
                    _walk(target, depth + 1)
            except Exception:
                pass

        _walk(root, 0)
    except ImportError:
        pass
    return {"nodes": nodes, "edges": edges}


# ---------------------------------------------------------------------------
# AI Gateway — model config CRUD
# ---------------------------------------------------------------------------


@studio_router.get("/models")
async def list_models():
    return {"models": _store["models"]}


@studio_router.post("/models")
async def add_model(req: ModelConfigReq):
    for m in _store["models"]:
        if m["model_id"] == req.model_id:
            raise HTTPException(400, f"Model '{req.model_id}' already exists")
    entry = req.model_dump()
    _store["models"].append(entry)
    return entry


@studio_router.delete("/models/{model_id}")
async def remove_model(model_id: str):
    for i, m in enumerate(_store["models"]):
        if m["model_id"] == model_id:
            _store["models"].pop(i)
            return {"deleted": model_id}
    raise HTTPException(404, f"Model '{model_id}' not found")


@studio_router.get("/costs")
async def get_cost_summary():
    if not has_tier("pro"):
        raise HTTPException(402, "Cost tracking requires Pro tier or above.")
    totals: dict = {}
    for c in _store["costs"]:
        mid = c["model_id"]
        if mid not in totals:
            totals[mid] = {
                "model_id": mid,
                "total_input_tokens": 0,
                "total_output_tokens": 0,
                "total_cost_usd": 0.0,
                "request_count": 0,
            }
        totals[mid]["total_input_tokens"] += c.get("input_tokens", 0)
        totals[mid]["total_output_tokens"] += c.get("output_tokens", 0)
        totals[mid]["total_cost_usd"] += c.get("cost_usd", 0)
        totals[mid]["request_count"] += 1
    return {"costs": list(totals.values())}


@studio_router.post("/costs")
async def record_cost(
    model_id: str,
    input_tokens: int = 0,
    output_tokens: int = 0,
    cost_usd: float = 0.0,
):
    entry = {
        "model_id": model_id,
        "input_tokens": input_tokens,
        "output_tokens": output_tokens,
        "cost_usd": cost_usd,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
    _store["costs"].append(entry)
    return entry


# ---------------------------------------------------------------------------
# Scheduler — cron / webhook CRUD
# ---------------------------------------------------------------------------


@studio_router.get("/schedules")
async def list_schedules():
    return {"schedules": _store["schedules"]}


@studio_router.post("/schedules")
async def create_schedule(req: ScheduleReq):
    for s in _store["schedules"]:
        if s["name"] == req.name:
            raise HTTPException(400, f"Schedule '{req.name}' already exists")
    entry = req.model_dump()
    entry["enabled"] = True
    entry["last_run"] = ""
    _store["schedules"].append(entry)
    return entry


@studio_router.put("/schedules/toggle")
async def toggle_schedule(req: ToggleReq):
    for s in _store["schedules"]:
        if s["name"] == req.name:
            s["enabled"] = req.enabled
            return s
    raise HTTPException(404, f"Schedule '{req.name}' not found")


@studio_router.delete("/schedules/{name}")
async def delete_schedule(name: str):
    for i, s in enumerate(_store["schedules"]):
        if s["name"] == name:
            _store["schedules"].pop(i)
            return {"deleted": name}
    raise HTTPException(404, f"Schedule '{name}' not found")


# ---------------------------------------------------------------------------
# Sandbox — Jac code execution
# ---------------------------------------------------------------------------


@studio_router.post("/sandbox/run")
async def run_sandbox(req: SandboxReq):
    session_id = str(uuid.uuid4())[:8]
    output_text = ""
    status = "error"

    try:
        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".jac", delete=False
        ) as f:
            f.write(req.code)
            tmp_path = f.name

        try:
            proc = subprocess.run(
                ["jac", "run", tmp_path],
                capture_output=True,
                text=True,
                timeout=req.timeout_sec,
            )
            output_text = proc.stdout
            if proc.returncode != 0:
                output_text = proc.stdout + "\n" + proc.stderr
            else:
                status = "success"
        except subprocess.TimeoutExpired:
            output_text = f"Execution timed out after {req.timeout_sec}s"
            status = "timeout"
        finally:
            os.unlink(tmp_path)
    except Exception as e:
        output_text = str(e)

    record = {
        "session_id": session_id,
        "code": req.code,
        "output": output_text,
        "status": status,
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    _store["sandbox"].append(record)
    return record


@studio_router.get("/sandbox/history")
async def get_sandbox_history(limit: int = 10):
    sessions = sorted(
        _store["sandbox"], key=lambda s: s["created_at"], reverse=True
    )
    return {"sessions": sessions[:limit]}


# ---------------------------------------------------------------------------
# Tier info
# ---------------------------------------------------------------------------


@studio_router.get("/tier")
async def get_tier():
    return {"tier": get_license_tier(), "has_pro": has_tier("pro"), "has_enterprise": has_tier("enterprise")}
