"""Example sizing tool — V4 PACK template (Tier 3).

This is a pedagogical stub showing the V4 Tool conventions:
- Pure function (no globals, no IO outside the call boundary)
- Returns dict matching tool.yaml's `returns` JSONSchema
- Raises ToolError with explicit reason when inputs are out of supported range

See docs/v4/V4_TOOL_API_SPEC.md for the full contract.
"""

from __future__ import annotations

from typing import TypedDict


# ---------------------------------------------------------------------------
# PDK process constants (per V4_KNOWLEDGE_FORMAT §6.7 — must annotate @ pdk)
# ---------------------------------------------------------------------------
# vpdk180nm typical TT @ 27°C — these are illustrative, not authoritative.
# Real tool should query the pdk knowledge package or run a characterization
# script to get up-to-date constants.

_PROCESS_CONSTANTS = {
    "vpdk180nm": {
        "mu_cox_n": 270e-6,  # A/V^2  (NMOS μn·Cox)
        "mu_cox_p": 67e-6,   # A/V^2  (PMOS μp·Cox)
    },
}


class ToolError(Exception):
    """Raised when the tool cannot serve the request (invalid input, unsupported pdk, …)."""


class HandleResult(TypedDict):
    W: float
    L: float
    m: int
    sizing_spice_fragment: str


def handle(
    *,
    pdk_name: str,
    device_type: str,
    Id_target: float,
    Vov_target: float,
) -> HandleResult:
    """Compute (W, L, m) from spec for a single device in strong inversion.

    Uses square-law: gm = √(2 · μ·Cox · W/L · Id).
    Solves for W given (Id, Vov) at a fixed L=0.5 µm baseline.
    """
    if pdk_name not in _PROCESS_CONSTANTS:
        raise ToolError(f"Unsupported pdk: {pdk_name}. Supported: {sorted(_PROCESS_CONSTANTS)}")
    if device_type not in ("nmos", "pmos"):
        raise ToolError(f"device_type must be 'nmos' or 'pmos', got {device_type!r}")
    if Vov_target < 0.05 or Vov_target > 0.5:
        raise ToolError(f"Vov_target out of supported range [0.05, 0.5]: {Vov_target}")

    pc = _PROCESS_CONSTANTS[pdk_name]
    mu_cox = pc["mu_cox_n"] if device_type == "nmos" else pc["mu_cox_p"]

    # Square law:  Id = (μ·Cox/2) · (W/L) · Vov^2  →  W = 2·Id·L / (μ·Cox · Vov^2)
    L = 0.5e-6  # baseline 0.5 µm (matches V4 base-cells/current-mirror typical)
    W = 2.0 * Id_target * L / (mu_cox * Vov_target * Vov_target)

    # Pick m=1 by default; caller can scale up if W exceeds reasonable layout
    m = 1
    if W > 50e-6:  # > 50 µm finger → split into m
        m = max(1, int(W / 20e-6))
        W = W / m

    spice = (
        f"W={W * 1e6:.3g}u L={L * 1e6:.3g}u m={m}"
    )
    return HandleResult(W=W, L=L, m=m, sizing_spice_fragment=spice)
