* ==================================================================
* DC operating point — PNP bandgap (1.8 V, vpdk180nm)
* Purpose:
*   - confirm Vref settles to ≈ 1.19 V,
*   - OTA locks na = nb,
*   - three mirror legs + OTA tail all saturated,
*   - quiescent current in budget.
* ==================================================================

.lib '../../pdk/vpdk180nm/vpdk180nm_corners.lib' TT
.include './bandgap.cir'

VDD vdd 0 DC 1.8
VSS vss 0 0
Xdut vdd vss vref bandgap

.control
set noaskquit
op

* --- Key nodes ---
*   v(vref)      ≈ 1.19 V   bandgap output
*   v(xdut.na)   ≈ 0.65 V   Q1 emitter (= Vbe)
*   v(xdut.nb)   ≈ 0.65 V   Q2 sense node (OTA locks nb = na)
*   v(xdut.ny)   ≈ 0.60 V   Q2 emitter (na − ΔVbe)
*   v(xdut.yg)   ≈ 1.05 V   PMOS mirror gate (~ VDD − Vsg)
echo "=== Node voltages ==="
print v(vref) v(xdut.na) v(xdut.nb) v(xdut.ny) v(xdut.yg)

echo "=== Supply current ==="
print i(VDD)

* --- Mirror / core device op points ---
echo "=== PMOS mirror MP1/MP2/MP3 ==="
print @m.xdut.mp1[id] @m.xdut.mp1[vgs] @m.xdut.mp1[vds] @m.xdut.mp1[vdsat]
print @m.xdut.mp2[id] @m.xdut.mp2[vgs] @m.xdut.mp2[vds] @m.xdut.mp2[vdsat]
print @m.xdut.mp3[id] @m.xdut.mp3[vgs] @m.xdut.mp3[vds] @m.xdut.mp3[vdsat]

* ngspice hierarchical MOSFET refs use `m.<instance>` per subckt level:
* xamp inside xdut → `m.xdut.m.xamp.<dev>`.
echo "=== OTA diff pair (xamp.m1/m2) ==="
print @m.xdut.m.xamp.m1[id] @m.xdut.m.xamp.m1[vgs] @m.xdut.m.xamp.m1[vds] @m.xdut.m.xamp.m1[vdsat]
print @m.xdut.m.xamp.m2[id] @m.xdut.m.xamp.m2[vgs] @m.xdut.m.xamp.m2[vds] @m.xdut.m.xamp.m2[vdsat]

echo "=== OTA tail + output ==="
print @m.xdut.m.xamp.m_tail[id] @m.xdut.m.xamp.m_tail[vgs] @m.xdut.m.xamp.m_tail[vds] @m.xdut.m.xamp.m_tail[vdsat]
print @m.xdut.m.xamp.m_out[id] @m.xdut.m.xamp.m_out[vgs] @m.xdut.m.xamp.m_out[vds] @m.xdut.m.xamp.m_out[vdsat]
print @m.xdut.m.xamp.m_load[id] @m.xdut.m.xamp.m_load[vgs] @m.xdut.m.xamp.m_load[vds] @m.xdut.m.xamp.m_load[vdsat]

* --- FOM summary (ngspice lacks `.meas op`; use let + print) ---
let v_vref      = v(vref)
let v_na        = v(xdut.na)
let v_nb        = v(xdut.nb)
let v_ny        = v(xdut.ny)
let v_yg        = v(xdut.yg)
let ota_lock_err = abs(v(xdut.na) - v(xdut.nb))
let i_vdd       = i(VDD)
let i_quiescent = abs(i(VDD))
let vref_err    = abs(v(vref) - 1.19)

echo "=== FOM summary ==="
print v_vref v_na v_nb v_ny v_yg ota_lock_err i_vdd i_quiescent vref_err

wrdata dc_op.dat v(vref) v(xdut.na) v(xdut.nb) v(xdut.ny) v(xdut.yg) i(VDD)
quit
.endc

.end
