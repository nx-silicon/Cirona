"""Smoke tests for the example sizing tool.

Tier-3 PACK 必须为 Tool 提供测试（V4_TOOL_API_SPEC §6）。本文件演示最小测试集：
- 正常路径返回值字段完整 + 数量级合理
- 输入越界正确抛 ToolError
"""

from __future__ import annotations

import math
import pytest

from ..handler import ToolError, handle


def test_nmos_typical_returns_reasonable_sizing():
    out = handle(
        pdk_name="vpdk180nm",
        device_type="nmos",
        Id_target=10e-6,
        Vov_target=0.15,
    )
    assert {"W", "L", "m", "sizing_spice_fragment"} <= out.keys()
    # Typical NMOS @ Id=10u Vov=0.15 should yield W ~ 1-30 um
    assert 0.5e-6 < out["W"] < 100e-6
    assert out["L"] == pytest.approx(0.5e-6)
    assert out["m"] >= 1
    assert "W=" in out["sizing_spice_fragment"]


def test_pmos_needs_larger_W_due_to_lower_mobility():
    nmos = handle(pdk_name="vpdk180nm", device_type="nmos",
                  Id_target=10e-6, Vov_target=0.15)
    pmos = handle(pdk_name="vpdk180nm", device_type="pmos",
                  Id_target=10e-6, Vov_target=0.15)
    # PMOS μp·Cox ≈ 1/4 of NMOS → W should be ~3-5x larger for same Vov, Id
    assert pmos["W"] * pmos["m"] > nmos["W"] * nmos["m"] * 2.0


def test_invalid_pdk_raises():
    with pytest.raises(ToolError, match="Unsupported pdk"):
        handle(pdk_name="bogus", device_type="nmos",
               Id_target=10e-6, Vov_target=0.15)


def test_vov_out_of_range_raises():
    with pytest.raises(ToolError, match="Vov_target out of"):
        handle(pdk_name="vpdk180nm", device_type="nmos",
               Id_target=10e-6, Vov_target=2.0)
