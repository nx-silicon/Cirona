* AC Gain & Bandwidth Testbench (Method C — Rfb+Cfb shunt, vinp injection)
* Circuit: two_stage_ota_se
* Open-loop transfer function measured via DC-closed / AC-open.
* Reference: backend/src/kernel/methods/ac_loop_break.md
*
* Conventions enforced here (L0/L1 rails):
*   - `set units = degrees` fixes vp() + wrdata to degrees globally.
*   - Anchor-difference PM formula (universal; replaces the old
*     `PM = 180 + phase_at_ugf` which only works for Method C
*     non-inverting and gives nonsense elsewhere).
*   - `setplot ac1` before any `meas ac` so phase_deg/gain_db resolve.
*   - DC and AC excitation consistent: Vinp/Ibias identical in both
*     sweeps; VTEST-style sources are absent (Method C has no VTEST).
.lib '../../pdk/vpdk180nm/vpdk180nm_corners.lib' TT
.include './two_stage_ota.cir'

* --- Supplies ---
Vdd vdd 0 DC 1.8
Vss vss 0 DC 0

* --- External bias ---
Ibias vdd ibias DC 10u

* --- Common-mode reference + non-inverting-input AC injection ---
Vcm  vcm  0   DC 0.9
Vinp vinp vcm DC 0 AC 1

* --- DC feedback path (unity-gain buffer at DC) + AC loop break ---
Rfb vout vinn 1e9    $ 1 GOhm: DC path vout -> vinn
Cfb vinn 0    1      $ 1 F   : AC ground for vinn

* --- DUT ---
X1 vinp vinn vout ibias vdd vss two_stage_ota_se

* --- Load ---
CL vout 0 5p

.control
set noaskquit
set units = degrees             $ global: vp()/wrdata output in degrees
ac dec 50 1 1G
setplot ac1                     $ required: switch curplot to AC results

let gain_db   = db(abs(v(vout)))
let phase_deg = vp(vout)        $ already in degrees via `set units`

meas ac dc_gain      find gain_db   at=1
meas ac ugf          when gain_db=0 cross=1
meas ac phase_dc     find phase_deg at=1
meas ac phase_at_ugf find phase_deg when gain_db=0 cross=1

* Anchor-difference PM (works for any sign/wrap; see ac_loop_break.md).
let phase_loss = phase_dc - phase_at_ugf
let pm         = 180 - phase_loss

echo "=== AC Results ==="
print dc_gain ugf phase_dc phase_at_ugf pm
wrdata ac_bode.dat gain_db phase_deg
quit
.endc
.end
