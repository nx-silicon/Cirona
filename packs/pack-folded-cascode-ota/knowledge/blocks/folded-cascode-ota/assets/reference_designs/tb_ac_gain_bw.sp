* AC Gain & Bandwidth Testbench (Method C — Rfb+Cfb shunt, vinp injection)
* Circuit: folded_cascode_ota (self-contained bias tree, ibias only)
* Open-loop transfer function measured via DC-closed / AC-open.
* Reference: backend/src/kernel/methods/ac_loop_break.md
.lib '../../pdk/vpdk180nm/vpdk180nm_corners.lib' TT
.include './fc_ota.cir'

Vdd vdd 0 DC 1.8
Vss vss 0 DC 0

Ibias vdd ibias DC 10u

Vcm  vcm  0   DC 0.9
Vinp vinp vcm DC 0 AC 1

Rfb vout vinn 1e9
Cfb vinn 0    1

X1 vinp vinn vout ibias vdd vss folded_cascode_ota

CL vout 0 2p

.control
set noaskquit
set units = degrees
ac dec 50 1 1G
setplot ac1

let gain_db   = db(abs(v(vout)))
let phase_deg = vp(vout)

meas ac dc_gain      find gain_db   at=1
meas ac ugf          when gain_db=0 cross=1
meas ac phase_dc     find phase_deg at=1
meas ac phase_at_ugf find phase_deg when gain_db=0 cross=1

let phase_loss = phase_dc - phase_at_ugf
let pm         = 180 - phase_loss

echo "=== AC Results ==="
print dc_gain ugf phase_dc phase_at_ugf pm
wrdata ac_bode.dat gain_db phase_deg
quit
.endc
.end
