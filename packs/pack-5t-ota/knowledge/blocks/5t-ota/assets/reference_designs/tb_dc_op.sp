* DC Operating Point Testbench
* Circuit: five_transistor_ota
* Configuration: open-loop, both inputs at VCM
* Checks ALL devices for saturation (|vds| > |vdsat|)
.lib '../../pdk/vpdk180nm/vpdk180nm_corners.lib' TT
.include './5t_ota.cir'

VDD vdd 0 1.8
VSS vss 0 0
IBIAS vdd ibias DC 10u

VINP vinp 0 DC 0.9
VINN vinn 0 DC 0.9

X1 vinp vinn ibias out vdd vss five_transistor_ota

CL out 0 2p

.control
set noaskquit
op
print all
echo "=== NMOS Differential Pair (M1, M2) ==="
print @m.x1.m1[id] @m.x1.m1[gm] @m.x1.m1[vgs] @m.x1.m1[vds] @m.x1.m1[vdsat]
print @m.x1.m2[id] @m.x1.m2[gm] @m.x1.m2[vgs] @m.x1.m2[vds] @m.x1.m2[vdsat]
echo "=== PMOS Mirror Load (M3, M4) ==="
print @m.x1.m3[id] @m.x1.m3[gm] @m.x1.m3[vgs] @m.x1.m3[vds] @m.x1.m3[vdsat]
print @m.x1.m4[id] @m.x1.m4[gm] @m.x1.m4[vgs] @m.x1.m4[vds] @m.x1.m4[vdsat]
echo "=== NMOS Tail Current Source (M5) ==="
print @m.x1.m5[id] @m.x1.m5[gm] @m.x1.m5[vgs] @m.x1.m5[vds] @m.x1.m5[vdsat]
echo "=== NMOS Bias Reference (Mbias) ==="
print @m.x1.mbias[id] @m.x1.mbias[gm] @m.x1.mbias[vgs] @m.x1.mbias[vds] @m.x1.mbias[vdsat]
echo "=== Saturation Margin (|vds| - |vdsat|, positive = saturated) ==="
let sat_m1 = abs(@m.x1.m1[vds]) - abs(@m.x1.m1[vdsat])
let sat_m2 = abs(@m.x1.m2[vds]) - abs(@m.x1.m2[vdsat])
let sat_m3 = abs(@m.x1.m3[vds]) - abs(@m.x1.m3[vdsat])
let sat_m4 = abs(@m.x1.m4[vds]) - abs(@m.x1.m4[vdsat])
let sat_m5 = abs(@m.x1.m5[vds]) - abs(@m.x1.m5[vdsat])
print sat_m1 sat_m2 sat_m3 sat_m4 sat_m5
quit
.endc
.end
