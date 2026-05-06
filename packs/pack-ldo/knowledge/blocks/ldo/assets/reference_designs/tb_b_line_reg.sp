* ==================================================================
* Testbench A.LINE_REG — Topology A, Vin ±10% sweep @ Iload=10mA
* ==================================================================
* Test Vdd = 1.62V → 1.98V (±10% around 1.8V nominal)
* line_reg = ΔVout / ΔVin (mV/V)
* ==================================================================

.lib '../../pdk/vpdk180nm/vpdk180nm_corners.lib' TT
.include './ldo_5t_pmos_in_sf.cir'

Vdd   vdd  0  DC 1.8
Vref  vref 0  DC 0.9
Ibias vdd  ibias DC 5u

Cload vout vout_cap 1u
Resr  vout_cap 0    5

Iload vout 0 DC 10m

X1 vdd 0 vout ibias vref vfb_node ldo_5t_pmos_in_sf

.dc Vdd 1.60 2.00 0.02

.control
set noaskquit
run

echo "=== Line Regulation Sweep (Vdd 1.62 → 1.98V, ±10%) ==="
meas dc vout_at_1p62 find v(vout) at=1.62
meas dc vout_at_1p80 find v(vout) at=1.80
meas dc vout_at_1p98 find v(vout) at=1.98

print vout_at_1p62
print vout_at_1p80
print vout_at_1p98

let line_reg_mV_per_V = abs(vout_at_1p98 - vout_at_1p62) / 0.36 * 1000
print line_reg_mV_per_V

wrdata tb_a_line_reg.dat v(vout)

quit
.endc
.end
