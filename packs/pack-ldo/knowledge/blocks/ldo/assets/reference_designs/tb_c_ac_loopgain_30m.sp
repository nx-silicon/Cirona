* ==================================================================
* Testbench A.AC_LOOPGAIN_30m — Topology C (FC + direct + Ahuja)), AC loop gain
* ==================================================================
* Method C with internal R-divider:
*   - Internal R1+R2 in subckt provides DC closure (no Rfb needed for DC)
*   - Cfb at vfb_dc (external) AC-grounds the injection node
*   - Vinj between vfb_node (subckt vfb port) and vfb_dc forces V(vfb)=1V AC
*   - Internal divider's AC contribution overridden by Vinj voltage source
*
* Measured: forward gain A(s) = V(vout)/V(vfb)_AC = V(vout) (since V(vfb)=1V)
* Loop gain T(s) = A(s) × β where β = R2/(R1+R2) = 0.75 → T_db = A_db - 2.5 dB
* UGF of T = freq where |A|=2.5 dB; PM measured at that freq.
* ==================================================================

.lib '../../pdk/vpdk180nm/vpdk180nm_corners.lib' TT
.include './ldo_fc_buffer.cir'

Vdd   vdd  0  DC 1.8
Vref  vref 0  DC 0.9
Ibias vdd  ibias DC 5u

Cload vout vout_cap 1u
Resr  vout_cap 0    5

Iload vout 0 DC 30m

* Method C external network for AC injection at vfb
Rfb   vout      vfb_dc 1e9
Cfb   vfb_dc    0      1
Vinj  vfb_node  vfb_dc DC 0 AC 1

X1 vdd 0 vout ibias vref vfb_node ldo_fc_buffer

.control
set noaskquit
set units = degrees
ac dec 50 1 1G
setplot ac1

* Forward gain A(s) = V(vout)/V(vfb_AC); since V(vfb)=1V AC, A = V(vout)
let A_db    = db(abs(v(vout)))
* Use cph() for continuous (unwrapped) phase — avoids ±180° wrap that
* breaks abs-difference PM formula when loop has multiple poles
let A_phase = cph(v(vout))

* Loop gain T = A × β = A × 0.75 → T_db = A_db - 2.5
let T_db = A_db - 2.5

meas ac dc_gain      find T_db    at=1
meas ac ugf          when T_db=0  cross=1
meas ac phase_dc     find A_phase at=1
meas ac phase_at_ugf find A_phase when T_db=0 cross=1

* Robust PM via "shortest-arc" phase difference (handles ±180° wrap):
*   raw_diff = |phase_dc − phase_at_ugf| mod 360
*   short_diff = min(raw_diff, 360 − raw_diff)  → in [0, 180°]
*   PM = 180 − short_diff
let phase_loss_abs = abs(phase_dc - phase_at_ugf)
let phase_loss_short = min(phase_loss_abs, 360 - phase_loss_abs)
let pm_deg = 180 - phase_loss_short

echo "=== AC Loop Gain Results (Topology A, Iload=30m) ==="
print dc_gain
print ugf
print phase_dc
print phase_at_ugf
print phase_loss_abs
print pm_deg

wrdata tb_a_ac_loopgain_10mA.dat A_db A_phase

quit
.endc
.end
