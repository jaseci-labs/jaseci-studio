"""License tier detection and feature gating."""

from __future__ import annotations

import os
import logging

logger = logging.getLogger(__name__)

# Tier hierarchy (higher = more features)
TIER_ORDER = {"free": 0, "pro": 1, "enterprise": 2}


def get_license_tier() -> str:
    """Detect the current license tier.

    Priority:
    1. JASECI_LICENSE_TIER env var (explicit override).
    2. If jaseci-enterprise is installed → "enterprise".
    3. JASECI_LICENSE_KEY env var → "pro".
    4. Fallback → "free".
    """
    override = os.getenv("JASECI_LICENSE_TIER", "")
    if override in TIER_ORDER:
        return override

    try:
        import jaseci_enterprise  # noqa: F401
        return "enterprise"
    except ImportError:
        pass

    key = os.getenv("JASECI_LICENSE_KEY", "")
    if key:
        return "pro"

    return "free"


def has_tier(minimum: str) -> bool:
    """Check if the current tier meets the minimum requirement."""
    current = get_license_tier()
    return TIER_ORDER.get(current, 0) >= TIER_ORDER.get(minimum, 0)


def require_tier(minimum: str):
    """FastAPI dependency that gates endpoints by license tier.

    Usage::

        @router.get("/pro-feature")
        async def pro_feature(_=require_tier("pro")):
            ...
    """
    from fastapi import Depends, HTTPException, Request

    def _check(request: Request):  # noqa: ARG001
        current = get_license_tier()
        if TIER_ORDER.get(current, 0) < TIER_ORDER.get(minimum, 0):
            raise HTTPException(
                status_code=402,
                detail=(
                    f"This feature requires the '{minimum}' tier. "
                    f"Current tier: '{current}'. "
                    "Set JASECI_LICENSE_KEY or install jaseci-enterprise."
                ),
            )

    return Depends(_check)
