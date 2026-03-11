"""Jaseci Studio plugin — mounts Studio UI and API routes onto a running server."""

from __future__ import annotations

import logging
from pathlib import Path

logger = logging.getLogger(__name__)

_CLIENT_DIST = Path(__file__).parent / "client" / "dist"


def mount_studio(app: object) -> None:
    """Mount Studio routes and static UI onto a FastAPI app.

    Call this from a jac-scale or jaseci-enterprise create_server hook,
    or directly in a standalone FastAPI setup::

        from jaseci_studio.plugin import mount_studio
        mount_studio(app)
    """
    from fastapi import FastAPI
    from fastapi.staticfiles import StaticFiles

    if not isinstance(app, FastAPI):
        logger.warning("mount_studio: expected FastAPI app, got %s", type(app))
        return

    from jaseci_studio.api.routes import studio_router

    app.include_router(studio_router)

    if _CLIENT_DIST.is_dir():
        app.mount(
            "/_studio",
            StaticFiles(directory=str(_CLIENT_DIST), html=True),
            name="jaseci-studio-ui",
        )
        logger.info("Jaseci Studio UI mounted at /_studio")
    else:
        logger.warning("Studio client dist not found at %s", _CLIENT_DIST)
