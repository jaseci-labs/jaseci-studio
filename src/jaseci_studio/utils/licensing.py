"""License tier detection and feature gating."""

from __future__ import annotations

import os
import logging

logger = logging.getLogger(__name__)

# Tier hierarchy (higher = more features)
TIER_ORDER = {"free": 0, "pro": 1, "enterprise": 2}


def get_license_tier() -> str:
    """Detect the current license tier.

    1. If jaseci-enterprise is installed, delegates to its license validator.
    2. Falls back to "free" when enterprise is absent or has no key.
    """
    try:
        from jaseci_enterprise.plugin import get_license_tier as _enterprise_tier
        return _enterprise_tier()
    except ImportError:
        pass

    # No enterprise package — check for a standalone key (future)
    key = os.getenv("JASECI_LICENSE_KEY", "")
    if not key:
        return "free"

    # For now, any key without enterprise = free
    logger.debug("License key present but jaseci-enterprise not installed.")
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
