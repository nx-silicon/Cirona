* ==================================================================
* Testbench A.LOAD_REG — Topology A, Iload sweep 0→30mA @ Vdd=1.8V
* ==================================================================
* Critical test for R-divider Ibleed bug detection:
*   @ Iload=0, Vout should remain at Vnom (~1.2V) thanks to internal
*   R1+R2 divider providing Ibleed=30µA. If Vout drifts toward Vdd,
*   the divider isn't working (LDO design bug).
* ==================================================================

.lib '../../pdk/vpdk180nm/vpdk180nm_corners.lib' TT
.include './ldo_5t_pmos_in_sf.cir'

Vdd   vdd  0  DC 1.8
Vref  vref 0  DC 0.9
Ibias vdd  ibias DC 5u

Cload vout vout_cap 1u
Resr  vout_cap 0    5

Iload vout 0 DC 0

X1 vdd 0 vout ibias vref vfb_node ldo_5t_pmos_in_sf

.dc Iload 0 30m 1m

.control
set noaskquit
run

echo "=== Load Regulation Sweep (Iload 0 → 30mA) ==="
meas dc vout_at_0    find v(vout) at=0
meas dc vout_at_1m   find v(vout) at=1m
meas dc vout_at_10m  find v(vout) at=10m
meas dc vout_at_30m  find v(vout) at=30m

print vout_at_0
print vout_at_1m
print vout_at_10m
print vout_at_30m

let load_reg_30m_mV  = abs(vout_at_30m - vout_at_0) * 1000
print load_reg_30m_mV

* Save sweep data
wrdata tb_a_load_reg.dat v(vout)

quit
.endc
.end
