* DC Operating Point Testbench
* Circuit: folded_cascode_ota (bias tree integrated)
* Configuration: open-loop, both inputs at VCM
* Checks ALL devices for saturation (|vds| > |vdsat|)
.lib '../../pdk/vpdk180nm/vpdk180nm_corners.lib' TT
.include './fc_ota.cir'

VDD vdd 0 1.8
VSS vss 0 0
IBIAS vdd ibias DC 10u

VINP vinp 0 DC 0.9
VINN vinn 0 DC 0.9


X1 vinp vinn vout ibias vdd vss folded_cascode_ota

CL vout 0 2p

.control
set noaskquit
op
print all
echo "=== Group 1: NMOS Differential Pair (MN1, MN2) ==="
print @m.x1.mn1[id] @m.x1.mn1[gm] @m.x1.mn1[vgs] @m.x1.mn1[vds] @m.x1.mn1[vdsat]
print @m.x1.mn2[id] @m.x1.mn2[gm] @m.x1.mn2[vgs] @m.x1.mn2[vds] @m.x1.mn2[vdsat]
echo "=== Group 1: Tail Current Source (MNtail) ==="
print @m.x1.mntail[id] @m.x1.mntail[gm] @m.x1.mntail[vgs] @m.x1.mntail[vds] @m.x1.mntail[vdsat]
echo "=== Group 2: PMOS Fold Current Source (MP1_bottom, MP3_bottom) ==="
print @m.x1.mp1_bottom[id] @m.x1.mp1_bottom[gm] @m.x1.mp1_bottom[vgs] @m.x1.mp1_bottom[vds] @m.x1.mp1_bottom[vdsat]
print @m.x1.mp3_bottom[id] @m.x1.mp3_bottom[gm] @m.x1.mp3_bottom[vgs] @m.x1.mp3_bottom[vds] @m.x1.mp3_bottom[vdsat]
echo "=== Group 3: PMOS Cascode (MP2_top, MP4_top) ==="
print @m.x1.mp2_top[id] @m.x1.mp2_top[gm] @m.x1.mp2_top[vgs] @m.x1.mp2_top[vds] @m.x1.mp2_top[vdsat]
print @m.x1.mp4_top[id] @m.x1.mp4_top[gm] @m.x1.mp4_top[vgs] @m.x1.mp4_top[vds] @m.x1.mp4_top[vdsat]
echo "=== Group 5: NMOS Current Mirror (MN5_bottom, MN7_bottom) ==="
print @m.x1.mn5_bottom[id] @m.x1.mn5_bottom[gm] @m.x1.mn5_bottom[vgs] @m.x1.mn5_bottom[vds] @m.x1.mn5_bottom[vdsat]
print @m.x1.mn7_bottom[id] @m.x1.mn7_bottom[gm] @m.x1.mn7_bottom[vgs] @m.x1.mn7_bottom[vds] @m.x1.mn7_bottom[vdsat]
echo "=== Group 4: NMOS Cascode (MN6_top, MN8_top) ==="
print @m.x1.mn6_top[id] @m.x1.mn6_top[gm] @m.x1.mn6_top[vgs] @m.x1.mn6_top[vds] @m.x1.mn6_top[vdsat]
print @m.x1.mn8_top[id] @m.x1.mn8_top[gm] @m.x1.mn8_top[vgs] @m.x1.mn8_top[vds] @m.x1.mn8_top[vdsat]
echo "=== Bias Reference (MMNbias) ==="
print @m.x1.mmnbias[id] @m.x1.mmnbias[gm] @m.x1.mmnbias[vgs] @m.x1.mmnbias[vds] @m.x1.mmnbias[vdsat]
echo "=== NMOS Mirrors (MMNfold_bias, MMN_vbcp_sink) ==="
print @m.x1.mmnfold_bias[id] @m.x1.mmnfold_bias[gm] @m.x1.mmnfold_bias[vgs] @m.x1.mmnfold_bias[vds] @m.x1.mmnfold_bias[vdsat]
print @m.x1.mmn_vbcp_sink[id] @m.x1.mmn_vbcp_sink[gm] @m.x1.mmn_vbcp_sink[vgs] @m.x1.mmn_vbcp_sink[vds] @m.x1.mmn_vbcp_sink[vdsat]
echo "=== vbias_fold Generator (MMPfold_bias) ==="
print @m.x1.mmpfold_bias[id] @m.x1.mmpfold_bias[gm] @m.x1.mmpfold_bias[vgs] @m.x1.mmpfold_bias[vds] @m.x1.mmpfold_bias[vdsat]
echo "=== vbc_p Generator (MMP_vbcp_1, MMP_vbcp_2) ==="
print @m.x1.mmp_vbcp_1[id] @m.x1.mmp_vbcp_1[gm] @m.x1.mmp_vbcp_1[vgs] @m.x1.mmp_vbcp_1[vds] @m.x1.mmp_vbcp_1[vdsat]
print @m.x1.mmp_vbcp_2[id] @m.x1.mmp_vbcp_2[gm] @m.x1.mmp_vbcp_2[vgs] @m.x1.mmp_vbcp_2[vds] @m.x1.mmp_vbcp_2[vdsat]
echo "=== vbc_n Generator (MMP_vbcn_src, MMN_vbcn_2, MMN_vbcn_1) ==="
print @m.x1.mmp_vbcn_src[id] @m.x1.mmp_vbcn_src[gm] @m.x1.mmp_vbcn_src[vgs] @m.x1.mmp_vbcn_src[vds] @m.x1.mmp_vbcn_src[vdsat]
print @m.x1.mmn_vbcn_2[id] @m.x1.mmn_vbcn_2[gm] @m.x1.mmn_vbcn_2[vgs] @m.x1.mmn_vbcn_2[vds] @m.x1.mmn_vbcn_2[vdsat]
print @m.x1.mmn_vbcn_1[id] @m.x1.mmn_vbcn_1[gm] @m.x1.mmn_vbcn_1[vgs] @m.x1.mmn_vbcn_1[vds] @m.x1.mmn_vbcn_1[vdsat]
echo "=== Saturation Margin (|vds| - |vdsat|, positive = saturated) ==="
let sat_mn1 = abs(@m.x1.mn1[vds]) - abs(@m.x1.mn1[vdsat])
print sat_mn1
let sat_mn2 = abs(@m.x1.mn2[vds]) - abs(@m.x1.mn2[vdsat])
print sat_mn2
let sat_mntail = abs(@m.x1.mntail[vds]) - abs(@m.x1.mntail[vdsat])
print sat_mntail
let sat_mp1_bottom = abs(@m.x1.mp1_bottom[vds]) - abs(@m.x1.mp1_bottom[vdsat])
print sat_mp1_bottom
let sat_mp3_bottom = abs(@m.x1.mp3_bottom[vds]) - abs(@m.x1.mp3_bottom[vdsat])
print sat_mp3_bottom
let sat_mp2_top = abs(@m.x1.mp2_top[vds]) - abs(@m.x1.mp2_top[vdsat])
print sat_mp2_top
let sat_mp4_top = abs(@m.x1.mp4_top[vds]) - abs(@m.x1.mp4_top[vdsat])
print sat_mp4_top
let sat_mn5_bottom = abs(@m.x1.mn5_bottom[vds]) - abs(@m.x1.mn5_bottom[vdsat])
print sat_mn5_bottom
let sat_mn7_bottom = abs(@m.x1.mn7_bottom[vds]) - abs(@m.x1.mn7_bottom[vdsat])
print sat_mn7_bottom
let sat_mn6_top = abs(@m.x1.mn6_top[vds]) - abs(@m.x1.mn6_top[vdsat])
print sat_mn6_top
let sat_mn8_top = abs(@m.x1.mn8_top[vds]) - abs(@m.x1.mn8_top[vdsat])
print sat_mn8_top
let sat_mmnbias = abs(@m.x1.mmnbias[vds]) - abs(@m.x1.mmnbias[vdsat])
print sat_mmnbias
let sat_mmnfold_bias = abs(@m.x1.mmnfold_bias[vds]) - abs(@m.x1.mmnfold_bias[vdsat])
print sat_mmnfold_bias
let sat_mmn_vbcp_sink = abs(@m.x1.mmn_vbcp_sink[vds]) - abs(@m.x1.mmn_vbcp_sink[vdsat])
print sat_mmn_vbcp_sink
let sat_mmpfold_bias = abs(@m.x1.mmpfold_bias[vds]) - abs(@m.x1.mmpfold_bias[vdsat])
print sat_mmpfold_bias
let sat_mmp_vbcp_1 = abs(@m.x1.mmp_vbcp_1[vds]) - abs(@m.x1.mmp_vbcp_1[vdsat])
print sat_mmp_vbcp_1
let sat_mmp_vbcp_2 = abs(@m.x1.mmp_vbcp_2[vds]) - abs(@m.x1.mmp_vbcp_2[vdsat])
print sat_mmp_vbcp_2
let sat_mmp_vbcn_src = abs(@m.x1.mmp_vbcn_src[vds]) - abs(@m.x1.mmp_vbcn_src[vdsat])
print sat_mmp_vbcn_src
let sat_mmn_vbcn_2 = abs(@m.x1.mmn_vbcn_2[vds]) - abs(@m.x1.mmn_vbcn_2[vdsat])
print sat_mmn_vbcn_2
let sat_mmn_vbcn_1 = abs(@m.x1.mmn_vbcn_1[vds]) - abs(@m.x1.mmn_vbcn_1[vdsat])
print sat_mmn_vbcn_1
quit
.endc
.end
