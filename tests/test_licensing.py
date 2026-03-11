"""Tests for the licensing utility."""

import os
from unittest.mock import patch

import pytest

from jaseci_studio.utils.licensing import get_license_tier, has_tier


def test_default_tier_is_free():
    with patch.dict(os.environ, {}, clear=True):
        assert get_license_tier() == "free"


def test_has_tier_free():
    with patch("jaseci_studio.utils.licensing.get_license_tier", return_value="free"):
        assert has_tier("free") is True
        assert has_tier("pro") is False
        assert has_tier("enterprise") is False


def test_has_tier_pro():
    with patch("jaseci_studio.utils.licensing.get_license_tier", return_value="pro"):
        assert has_tier("free") is True
        assert has_tier("pro") is True
        assert has_tier("enterprise") is False


def test_has_tier_enterprise():
    with patch("jaseci_studio.utils.licensing.get_license_tier", return_value="enterprise"):
        assert has_tier("free") is True
        assert has_tier("pro") is True
        assert has_tier("enterprise") is True
