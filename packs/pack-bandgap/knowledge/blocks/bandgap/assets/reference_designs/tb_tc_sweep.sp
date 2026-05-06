* ==================================================================
* Temperature sweep — PNP bandgap
* Purpose: measure Vref TC (ppm/°C) across −40/27/125 °C.
*   Three independent `op` calls at different `set temp` values; the
*   `let`-stored variables survive across `op` calls in ngspice .control.
* ==================================================================

.lib '../../pdk/vpdk180nm/vpdk180nm_corners.lib' TT
.include './bandgap.cir'

VDD vdd 0 DC 1.8
VSS vss 0 0
Xdut vdd vss vref bandgap

.control
set noaskquit

* ngspice quirk: each `op` rebuilds the plot; `let` variables from earlier
* `op` calls survive but don't always print with a bare `print` after a
* later `op`. Force immediate scalar capture with `$&var` inline echo,
* which reads the value at the exact moment the echo line runs.

set temp = -40
op
let vref_m40 = v(vref)
let i_vdd_m40 = i(VDD)
echo "TC: T=-40C  vref=$&vref_m40  i_vdd=$&i_vdd_m40"

set temp = 27
op
let vref_27 = v(vref)
let i_vdd_27 = i(VDD)
echo "TC: T= 27C  vref=$&vref_27  i_vdd=$&i_vdd_27"

set temp = 125
op
let vref_125 = v(vref)
let i_vdd_125 = i(VDD)
echo "TC: T=125C  vref=$&vref_125  i_vdd=$&i_vdd_125"

* TC coefficient = (Vref_max - Vref_min) / (Vref_27 * 165) * 1e6 [ppm/°C].
* Computed outside ngspice from the three points echoed above.
echo "TC coefficient (ppm/C) computed by host from the 3 points above."

* No wrdata here — `vref_m40/27/125` live in different plot scopes, and
* `wrdata` can only access the current plot. The echo lines above are
* the canonical output for host-side parsing.
quit
.endc

.end
