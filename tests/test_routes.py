"""Tests for the Studio API routes."""

import pytest
from fastapi.testclient import TestClient
from fastapi import FastAPI

from jaseci_studio.api.routes import studio_router, _store


@pytest.fixture(autouse=True)
def clean_store():
    """Reset in-memory store between tests."""
    for key in _store:
        _store[key].clear()
    yield
    for key in _store:
        _store[key].clear()


@pytest.fixture
def client():
    app = FastAPI()
    app.include_router(studio_router)
    return TestClient(app)


# -- Dashboard --

def test_dashboard(client):
    resp = client.get("/_studio/api/dashboard")
    assert resp.status_code == 200
    data = resp.json()
    assert data["total_runs"] == 0
    assert "tier" in data


def test_health(client):
    resp = client.get("/_studio/api/health")
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "healthy"
    assert "pid" in data


# -- Walkers --

def test_list_walkers(client):
    resp = client.get("/_studio/api/walkers")
    assert resp.status_code == 200
    assert "walkers" in resp.json()


def test_run_history_empty(client):
    resp = client.get("/_studio/api/walkers/history")
    assert resp.status_code == 200
    assert resp.json()["runs"] == []


# -- Models --

def test_add_and_list_models(client):
    resp = client.post("/_studio/api/models", json={
        "model_id": "gpt-4o",
        "provider": "openai",
    })
    assert resp.status_code == 200
    assert resp.json()["model_id"] == "gpt-4o"

    resp = client.get("/_studio/api/models")
    assert len(resp.json()["models"]) == 1


def test_add_duplicate_model(client):
    client.post("/_studio/api/models", json={"model_id": "gpt-4o"})
    resp = client.post("/_studio/api/models", json={"model_id": "gpt-4o"})
    assert resp.status_code == 400


def test_delete_model(client):
    client.post("/_studio/api/models", json={"model_id": "gpt-4o"})
    resp = client.delete("/_studio/api/models/gpt-4o")
    assert resp.status_code == 200
    assert resp.json()["deleted"] == "gpt-4o"
    assert len(client.get("/_studio/api/models").json()["models"]) == 0


def test_delete_model_not_found(client):
    resp = client.delete("/_studio/api/models/nope")
    assert resp.status_code == 404


# -- Schedules --

def test_create_and_list_schedules(client):
    resp = client.post("/_studio/api/schedules", json={
        "name": "nightly",
        "walker_name": "Report",
        "cron_expr": "0 2 * * *",
    })
    assert resp.status_code == 200
    assert resp.json()["name"] == "nightly"

    resp = client.get("/_studio/api/schedules")
    assert len(resp.json()["schedules"]) == 1


def test_toggle_schedule(client):
    client.post("/_studio/api/schedules", json={"name": "job1"})
    resp = client.put("/_studio/api/schedules/toggle", json={"name": "job1", "enabled": False})
    assert resp.status_code == 200
    assert resp.json()["enabled"] is False


def test_delete_schedule(client):
    client.post("/_studio/api/schedules", json={"name": "job1"})
    resp = client.delete("/_studio/api/schedules/job1")
    assert resp.status_code == 200
    assert resp.json()["deleted"] == "job1"


def test_delete_schedule_not_found(client):
    resp = client.delete("/_studio/api/schedules/nope")
    assert resp.status_code == 404


# -- Sandbox --

def test_sandbox_history_empty(client):
    resp = client.get("/_studio/api/sandbox/history")
    assert resp.status_code == 200
    assert resp.json()["sessions"] == []


# -- Tier --

def test_tier_endpoint(client):
    resp = client.get("/_studio/api/tier")
    assert resp.status_code == 200
    data = resp.json()
    assert "tier" in data
    assert "has_pro" in data
