# LDO Reference Designs — Multi-Topology PACK (v4)

This PACK provides 3 production-grade LDO reference netlists, each with a
complete P0 testbench suite. Use the topology selection guide to pick the
right reference for your spec, then `read_file` + adapt sizing.

## Topology Selection Guide

| File | Topology | DC gain | Iload (PM>45°) | Vref range | Best for |
|---|---|---:|---:|---|---|
| `ldo_5t_pmos_cs.cir` | **A**: NMOS-input 5T-OTA + PMOS-CS Stage 2 + Miller | ~93 dB | **1–30 mA** | ≥ 0.7 V (NMOS-input ICMR) | **Standard SoC LDO**, best line-reg, fastest tran |
| `ldo_5t_pmos_in_sf.cir` | **B**: PMOS-input 5T-OTA + PMOS Source-Follower buffer + Miller | ~78 dB | **0–30 mA** (full range) | ≤ 1.1 V (PMOS-input ICMR) | Wide Iload range, low-Vref apps |
| `ldo_fc_buffer.cir` | **C**: Folded-Cascode EA + PMOS SF buffer + adaptive pull-down + Ahuja | ~82 dB | **10–30 mA** | 0.4–1.4 V (FC wide ICMR) | Defined heavy-load apps, high-PSRR target |
| (TBD) | **D**: FVF dual-loop (capless / fast transient) | — | — | — | TBD |

All three subckts share a common interface: **6 ports** `vdd vss vout ibias vref vfb`,
where `vfb` is exposed for AC loop-gain testing (Method C). In production
DC/PSRR/Tran tests, leave `vfb` dangling — internal R1+R2 divider drives it.

## Common Iron Laws (all topologies)

1. **Internal R-divider** (R1 + R2 inside subckt) — provides
   `Ibleed = Vout/(R1+R2)` as light-load minimum current. **No separate
   M_bleed**. Default values: `R_R1=10k R_R2=30k` → Vout = Vref × 4/3.
2. **Mirror principle** — All NMOS sinks mirror Mbias with `W=W_bias L=L_bias`,
   only `m` varies. PMOS sources mirror M_pbias_p analogously.
3. **EA polarity** is topology-specific (see each cir's header):
   - A (NMOS-input 5T): vfb on M2 (mirror side, inverting)
   - B (PMOS-input 5T): vfb on M1 (diode side, non-inverting)
   - C (FC OTA): vfb on MN1 (left, non-inverting)
4. **PMOS pass FET** (default in all topologies) — `W=1400u L=0.5u m=1`.
   For higher Iload (>30mA), increase `m_pass` or topology-specific buffer.

## Testbench Suite (P0)

For each topology X (a/b/c), 4 testbench files cover P0 essentials:

| File | Purpose |
|---|---|
| `tb_X_dc_op_10mA.sp` | DC OP @ Iload=10mA — saturation margins, currents, Ibleed |
| `tb_X_ac_loopgain_10mA.sp` | AC loop gain (Method C) — DC gain, UGF, PM (>45° required) |
| `tb_X_load_reg.sp` | Load regulation 0→30mA — verify @0mA bleeder + ΔVout |
| `tb_X_line_reg.sp` | Line regulation Vin ±10% (1.62–1.98V) — ΔVout/ΔVin |

Run: `ngspice -b tb_<X>_<test>.cir` from this directory.

## Validated Test Results (vpdk180nm, TT, 27°C, Vref=0.9V → Vout=1.2V)

After sizing tuning (m_pass=2 for all topologies; B: W_buf_p=16u; C: Cc=200p,
I_buf=5u, W_buf=80u), all three topologies handle Iload 0–30mA cleanly.

### AC Loop Gain — Phase Margin × Iload sweep

| Iload  | A (5t_pmos_cs) | B (5t_pmos_in_sf) | C (fc_buffer) |
|--------|---:|---:|---:|
| 100 µA | 27° ⚠️ | **45°** ✓ | 30° ⚠️ |
| 1 mA   | 67° ✓ | 56° ✓ | 39° ⚠️ |
| 10 mA  | **77°** ✓ | 72° ✓ | 56° ✓ |
| 30 mA  | 64° ✓ | **81°** ✓ | 67° ✓ |

**B is the most robust across full Iload range** (light + heavy load PM > 45°).
A and C have light-load PM degradation (classic LDO light-load issue, fp_dom
moves to <1Hz as Rout_pass grows huge — ESR zero only partially compensates).

### Load Transient (Iload step 1mA → 10mA, 1µs slew)

| Topology | undershoot | overshoot |
|----------|---:|---:|
| A | **0.83 mV** | 0.29 mV |
| B | 36.3 mV | 25.4 mV |
| C | 35.8 mV | 33.7 mV |

A's high loop gain (~93dB) and 14 MHz UGF give exceptional transient response.
B/C have lower bandwidth (80–270 kHz UGF) → larger transient excursion but
still acceptable for typical LDO load-step specs (<100 mV).

### Static Regulation

| Topology | DC gain | UGF (10mA) | Load Reg (0→30mA) | Line Reg ±10% |
|----------|---:|---:|---|---|
| A | 93 dB | 14 MHz | 0.26 mV/30mA | **0.21 mV/V** |
| B | 78 dB | 112 kHz | 7.18 mV/30mA | 27 mV/V |
| C | 82 dB | 116 kHz | 3.03 mV/30mA | 8.08 mV/V |

A's high loop gain → best line regulation. B/C have lower DC gain but adequate
for medium-precision applications.

### Recommended Iload spec per topology

| Topology | Iload range (PM > 45°) | Best fit |
|----------|---|---|
| A | **1 mA – 30 mA** | Standard SoC LDO with min-load spec |
| B | **0 – 30 mA** (full range) | Wide Iload range, simple control |
| C | **10 mA – 30 mA** | High-precision, defined heavy-load apps |

For applications requiring < 1mA light-load operation with full PM margin,
add larger min-load (bigger R-divider current via smaller R_R1+R_R2) or
spec a minimum external load on the system board.

### Known limitations

- C topology has 2 NMOS cascode devices in mild triode (sat margin ~ −300mV)
  due to vbc_n bias gen — does not affect DC regulation but limits cascode
  gain boost. Tune cascode bias chain for production.
- A's light-load PM (27° @ 100µA) is acceptable for designs that guarantee
  Iload > 1mA. For wide-range LDO, use B topology or add nulling resistor
  (Rz in series with Cc) to shift Miller RHP zero.

## Testbench list (per topology X = a/b/c)

P0 testbenches (16 total = 5 tests × 3 topologies + 1 extra):
- `tb_X_dc_op_10mA.sp` — DC OP @ nominal 10mA
- `tb_X_ac_loopgain_100u.sp` / `_1m.cir` / `_10mA.cir` / `_30m.cir` — 4-point AC sweep
- `tb_X_load_reg.sp` — Load regulation 0→30mA
- `tb_X_line_reg.sp` — Line regulation Vin ±10%
- `tb_X_load_tran.sp` — Tran 1mA→10mA→1mA, 1µs slew

## Legacy

`ldo_5t_edu.cir` is a V3-era simplified educational netlist preserved for
reference. **Not** validated against v4 standards (no internal divider,
non-canonical EA polarity). Do not use for production designs.

## Related (load via knowledge tool, not read_file)

- Architecture selection: `load_knowledge(name='ldo', chapter='architecture')`
- Testbench conventions + P0 test suite: `load_knowledge(name='ldo', chapter='standard-tests')`
- Topology details (ASCII, polarity, sizing): each cir's header comment block
- AC stability: `load_knowledge(name='ldo', chapter='ac-stability')`
- PSRR: `load_knowledge(name='ldo', chapter='psrr')`
