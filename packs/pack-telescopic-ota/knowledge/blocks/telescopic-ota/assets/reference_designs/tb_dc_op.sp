* DC Operating Point Testbench
* Circuit: telescopic_ota (bias tree integrated)
* Configuration: open-loop, both inputs at VCM
* Checks ALL devices for saturation (|vds| > |vdsat|)
* NOTE: Padding devices (MMbnc_bot, MMbpc_top) are expected in LINEAR region.
.lib '../../pdk/vpdk180nm/vpdk180nm_corners.lib' TT
.include './telescopic_ota.cir'

VDD vdd 0 1.8
VSS vss 0 0
IBIAS vdd ibias DC 10u

VINP vinp 0 DC 0.9
VINN vinn 0 DC 0.9

X1 vinp vinn vout ibias vdd vss telescopic_ota

CL vout 0 2p

.control
set noaskquit
op
print all
echo "=== Differential Pair (MM1, MM2) ==="
print @m.x1.mm1[id] @m.x1.mm1[gm] @m.x1.mm1[vgs] @m.x1.mm1[vds] @m.x1.mm1[vdsat]
print @m.x1.mm2[id] @m.x1.mm2[gm] @m.x1.mm2[vgs] @m.x1.mm2[vds] @m.x1.mm2[vdsat]
echo "=== Tail Current Source (MMtail) ==="
print @m.x1.mmtail[id] @m.x1.mmtail[gm] @m.x1.mmtail[vgs] @m.x1.mmtail[vds] @m.x1.mmtail[vdsat]
echo "=== NMOS Cascode (MMcasc1, MMcasc2) ==="
print @m.x1.mmcasc1[id] @m.x1.mmcasc1[gm] @m.x1.mmcasc1[vgs] @m.x1.mmcasc1[vds] @m.x1.mmcasc1[vdsat]
print @m.x1.mmcasc2[id] @m.x1.mmcasc2[gm] @m.x1.mmcasc2[vgs] @m.x1.mmcasc2[vds] @m.x1.mmcasc2[vdsat]
echo "=== PMOS Cascode (MMcasp3, MMcasp4) ==="
print @m.x1.mmcasp3[id] @m.x1.mmcasp3[gm] @m.x1.mmcasp3[vgs] @m.x1.mmcasp3[vds] @m.x1.mmcasp3[vdsat]
print @m.x1.mmcasp4[id] @m.x1.mmcasp4[gm] @m.x1.mmcasp4[vgs] @m.x1.mmcasp4[vds] @m.x1.mmcasp4[vdsat]
echo "=== PMOS Load Mirror (MM3, MM4) ==="
print @m.x1.mm3[id] @m.x1.mm3[gm] @m.x1.mm3[vgs] @m.x1.mm3[vds] @m.x1.mm3[vdsat]
print @m.x1.mm4[id] @m.x1.mm4[gm] @m.x1.mm4[vgs] @m.x1.mm4[vds] @m.x1.mm4[vdsat]
echo "=== Bias Reference (MMbias) ==="
print @m.x1.mmbias[id] @m.x1.mmbias[gm] @m.x1.mmbias[vgs] @m.x1.mmbias[vds] @m.x1.mmbias[vdsat]
echo "=== N-to-P Conversion (MMbn2p, MMbp_ref) ==="
print @m.x1.mmbn2p[id] @m.x1.mmbn2p[gm] @m.x1.mmbn2p[vgs] @m.x1.mmbn2p[vds] @m.x1.mmbn2p[vdsat]
print @m.x1.mmbp_ref[id] @m.x1.mmbp_ref[gm] @m.x1.mmbp_ref[vgs] @m.x1.mmbp_ref[vds] @m.x1.mmbp_ref[vdsat]
echo "=== vbnc Generator (MMbp_nc, MMbnc_top, MMbnc_bot) ==="
print @m.x1.mmbp_nc[id] @m.x1.mmbp_nc[gm] @m.x1.mmbp_nc[vgs] @m.x1.mmbp_nc[vds] @m.x1.mmbp_nc[vdsat]
print @m.x1.mmbnc_top[id] @m.x1.mmbnc_top[gm] @m.x1.mmbnc_top[vgs] @m.x1.mmbnc_top[vds] @m.x1.mmbnc_top[vdsat]
print @m.x1.mmbnc_bot[id] @m.x1.mmbnc_bot[gm] @m.x1.mmbnc_bot[vgs] @m.x1.mmbnc_bot[vds] @m.x1.mmbnc_bot[vdsat]
echo "=== vbpc Generator (MMbn_pc, MMbpc_top, MMbpc_bot) ==="
print @m.x1.mmbn_pc[id] @m.x1.mmbn_pc[gm] @m.x1.mmbn_pc[vgs] @m.x1.mmbn_pc[vds] @m.x1.mmbn_pc[vdsat]
print @m.x1.mmbpc_top[id] @m.x1.mmbpc_top[gm] @m.x1.mmbpc_top[vgs] @m.x1.mmbpc_top[vds] @m.x1.mmbpc_top[vdsat]
print @m.x1.mmbpc_bot[id] @m.x1.mmbpc_bot[gm] @m.x1.mmbpc_bot[vgs] @m.x1.mmbpc_bot[vds] @m.x1.mmbpc_bot[vdsat]
echo "=== Saturation Margin (|vds| - |vdsat|, positive = saturated) ==="
echo "--- Gain-path devices (MUST be saturated) ---"
let sat_mm1 = abs(@m.x1.mm1[vds]) - abs(@m.x1.mm1[vdsat])
print sat_mm1
let sat_mm2 = abs(@m.x1.mm2[vds]) - abs(@m.x1.mm2[vdsat])
print sat_mm2
let sat_mmtail = abs(@m.x1.mmtail[vds]) - abs(@m.x1.mmtail[vdsat])
print sat_mmtail
let sat_mmcasc1 = abs(@m.x1.mmcasc1[vds]) - abs(@m.x1.mmcasc1[vdsat])
print sat_mmcasc1
let sat_mmcasc2 = abs(@m.x1.mmcasc2[vds]) - abs(@m.x1.mmcasc2[vdsat])
print sat_mmcasc2
let sat_mmcasp3 = abs(@m.x1.mmcasp3[vds]) - abs(@m.x1.mmcasp3[vdsat])
print sat_mmcasp3
let sat_mmcasp4 = abs(@m.x1.mmcasp4[vds]) - abs(@m.x1.mmcasp4[vdsat])
print sat_mmcasp4
let sat_mm3 = abs(@m.x1.mm3[vds]) - abs(@m.x1.mm3[vdsat])
print sat_mm3
let sat_mm4 = abs(@m.x1.mm4[vds]) - abs(@m.x1.mm4[vdsat])
print sat_mm4
echo "--- Bias tree devices (MUST be saturated) ---"
let sat_mmbias = abs(@m.x1.mmbias[vds]) - abs(@m.x1.mmbias[vdsat])
print sat_mmbias
let sat_mmbn2p = abs(@m.x1.mmbn2p[vds]) - abs(@m.x1.mmbn2p[vdsat])
print sat_mmbn2p
let sat_mmbp_ref = abs(@m.x1.mmbp_ref[vds]) - abs(@m.x1.mmbp_ref[vdsat])
print sat_mmbp_ref
let sat_mmbp_nc = abs(@m.x1.mmbp_nc[vds]) - abs(@m.x1.mmbp_nc[vdsat])
print sat_mmbp_nc
let sat_mmbnc_top = abs(@m.x1.mmbnc_top[vds]) - abs(@m.x1.mmbnc_top[vdsat])
print sat_mmbnc_top
let sat_mmbn_pc = abs(@m.x1.mmbn_pc[vds]) - abs(@m.x1.mmbn_pc[vdsat])
print sat_mmbn_pc
let sat_mmbpc_bot = abs(@m.x1.mmbpc_bot[vds]) - abs(@m.x1.mmbpc_bot[vdsat])
print sat_mmbpc_bot
echo "--- Padding devices (expected in LINEAR, negative is OK) ---"
let sat_mmbnc_bot = abs(@m.x1.mmbnc_bot[vds]) - abs(@m.x1.mmbnc_bot[vdsat])
print sat_mmbnc_bot
let sat_mmbpc_top = abs(@m.x1.mmbpc_top[vds]) - abs(@m.x1.mmbpc_top[vdsat])
print sat_mmbpc_top
echo "=== Key Bias Voltages ==="
print v(ibias) v(vbnc) v(vbpc) v(nbias_p) v(vout)
quit
.endc
.end
