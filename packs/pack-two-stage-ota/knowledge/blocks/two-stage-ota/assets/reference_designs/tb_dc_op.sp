* DC Operating Point Testbench
* Circuit: two_stage_ota_se
.lib '../../pdk/vpdk180nm/vpdk180nm_corners.lib' TT
.include './two_stage_ota.cir'

VDD vdd 0 1.8
VSS vss 0 0
IBIAS vdd ibias DC 10u

VINP vinp 0 DC 0.9
VINN vinn 0 DC 0.9

X1 vinp vinn vout ibias vdd vss two_stage_ota_se

CL vout 0 5p

.control
set noaskquit
op
print all
echo "=== Bias Generation ==="
print @m.x1.mnbias[id] @m.x1.mnbias[vgs] @m.x1.mnbias[vds] @m.x1.mnbias[vdsat]
print @m.x1.mnsinkp[id] @m.x1.mnsinkp[vgs] @m.x1.mnsinkp[vds] @m.x1.mnsinkp[vdsat]
print @m.x1.mpbias[id] @m.x1.mpbias[vgs] @m.x1.mpbias[vds] @m.x1.mpbias[vdsat]
echo "=== First Stage: PMOS Diff Pair ==="
print @m.x1.mptail[id] @m.x1.mptail[gm] @m.x1.mptail[vgs] @m.x1.mptail[vds] @m.x1.mptail[vdsat]
print @m.x1.mp1[id] @m.x1.mp1[gm] @m.x1.mp1[vgs] @m.x1.mp1[vds] @m.x1.mp1[vdsat]
print @m.x1.mp2[id] @m.x1.mp2[gm] @m.x1.mp2[vgs] @m.x1.mp2[vds] @m.x1.mp2[vdsat]
echo "=== First Stage: NMOS Mirror Load ==="
print @m.x1.mn3[id] @m.x1.mn3[gm] @m.x1.mn3[vgs] @m.x1.mn3[vds] @m.x1.mn3[vdsat]
print @m.x1.mn4[id] @m.x1.mn4[gm] @m.x1.mn4[vgs] @m.x1.mn4[vds] @m.x1.mn4[vdsat]
echo "=== Second Stage ==="
print @m.x1.mn6[id] @m.x1.mn6[gm] @m.x1.mn6[vgs] @m.x1.mn6[vds] @m.x1.mn6[vdsat]
print @m.x1.mp6[id] @m.x1.mp6[gm] @m.x1.mp6[vgs] @m.x1.mp6[vds] @m.x1.mp6[vdsat]
echo "=== Saturation Margin ==="
let sat_mp1 = abs(@m.x1.mp1[vds]) - abs(@m.x1.mp1[vdsat])
let sat_mp2 = abs(@m.x1.mp2[vds]) - abs(@m.x1.mp2[vdsat])
let sat_mptail = abs(@m.x1.mptail[vds]) - abs(@m.x1.mptail[vdsat])
let sat_mn3 = abs(@m.x1.mn3[vds]) - abs(@m.x1.mn3[vdsat])
let sat_mn4 = abs(@m.x1.mn4[vds]) - abs(@m.x1.mn4[vdsat])
let sat_mn6 = abs(@m.x1.mn6[vds]) - abs(@m.x1.mn6[vdsat])
let sat_mp6 = abs(@m.x1.mp6[vds]) - abs(@m.x1.mp6[vdsat])
print sat_mp1 sat_mp2 sat_mptail sat_mn3 sat_mn4 sat_mn6 sat_mp6
quit
.endc
.end
