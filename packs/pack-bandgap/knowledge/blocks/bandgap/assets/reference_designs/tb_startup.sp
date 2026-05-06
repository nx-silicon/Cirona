* ==================================================================
* Startup transient — PNP bandgap
* Purpose: prove Vref escapes the zero-current state when VDD ramps up.
*   Always run this in addition to DC op — DC jumps to a non-zero
*   solution and will hide a broken startup branch.
* ==================================================================

.lib '../../pdk/vpdk180nm/vpdk180nm_corners.lib' TT
.include './bandgap.cir'

* VDD: single ramp 0 → 1.8 V over 1 µs, then hold. PW huge so no recurrence
* within the 200 µs simulation window.
VDD vdd 0 PULSE(0 1.8 0 1u 1u 10 20)
VSS vss 0 0
Xdut vdd vss vref bandgap

* With VDD ramping from 0 the whole circuit starts at V=0 naturally,
* so `.ic` is redundant and the solver can pick its own initial point.

.control
set noaskquit
tran 100n 200u uic

meas tran vref_final    find v(vref) at=190u
meas tran vref_max      max  v(vref) from=0   to=200u
meas tran vref_settled  min  v(vref) from=50u to=200u
meas tran yg_min        min  v(xdut.yg) from=0 to=200u
meas tran t_vref_90     when v(vref)=1.07 rise=1

echo "=== Startup results ==="
print vref_final vref_max vref_settled yg_min t_vref_90

wrdata bandgap_startup.dat v(vdd) v(vref) v(xdut.yg) v(xdut.v_sens)
quit
.endc

.end
