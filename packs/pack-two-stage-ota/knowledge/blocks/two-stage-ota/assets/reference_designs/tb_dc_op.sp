* DC Operating Point Testbench — open-loop (VINP=VINN forced)
* Circuit: two_stage_ota_se
*
* ⚠️ 不是默认 DC 模板。**优先用 tb_dc_closed.sp**（与 AC 共用激励）。
*
* 本模板的合法用途：mismatch=0 sanity 检查
*   - 当 closed-loop DC 出现某 device 不 saturation 时，用本模板做对照：
*     * 若 closed-loop fail 但 open-loop pass → 闭环 follower 把 vinn 拉到了
*       某个让 input pair 失衡的位置 (Rfb 太大 / stage1 mirror imbalance /
*       两级电流不匹配)。
*     * 若两个模板都 fail → sizing 真有问题 (tail headroom 不够 / input pair
*       极性错 / mirror W·m 算错)。
*   - 验证理想拓扑下各 device region 是否对，专门用来定位 sizing 问题。
*
* ⚠️ 注意：
*   - 本模板与 tb_ac_gain_bw.sp 激励**不一致**，跑出来的 OP 不能用来解读 AC。
*   - 高增益运放 (gain >> 60dB) open-loop 时，stage1/stage2 mismatch 会被
*     开环增益放大，vout 落点由器件 mismatch + 上下电流匹配度决定，
*     即使 VINP=VINN 数学相等也常飘 rail。这是物理规律，不是 sizing bug。

.lib '../../pdk/vpdk180nm/vpdk180nm_corners.lib' TT
.include './two_stage_ota.cir'

.param VDD   = 1.8
.param VCM   = 0.9
.param IBIAS = 10u
.param CLD   = 5p

VDD vdd 0 DC {VDD}
VSS vss 0 DC 0
IBIAS vdd ibias DC {IBIAS}

* Open-loop: BOTH inputs forced to Vcm — NO Rfb
VINP vinp 0 DC {VCM}
VINN vinn 0 DC {VCM}

X1 vinp vinn vout ibias vdd vss two_stage_ota_se

CL vout 0 {CLD}

.control
set noaskquit
op
print all
echo "=== Bias Generation ==="
print @m.x1.mnbias[id] @m.x1.mnbias[vgs] @m.x1.mnbias[vds] @m.x1.mnbias[vdsat]
print @m.x1.mnsinkp[id] @m.x1.mnsinkp[vgs] @m.x1.mnsinkp[vds] @m.x1.mnsinkp[vdsat]
print @m.x1.mpbias[id] @m.x1.mpbias[vgs] @m.x1.mpbias[vds] @m.x1.mpbias[vdsat]
echo "=== Stage1 input pair ==="
print @m.x1.mptail[id] @m.x1.mptail[gm] @m.x1.mptail[vgs] @m.x1.mptail[vds] @m.x1.mptail[vdsat]
print @m.x1.mp1[id] @m.x1.mp1[gm] @m.x1.mp1[vgs] @m.x1.mp1[vds] @m.x1.mp1[vdsat]
print @m.x1.mp2[id] @m.x1.mp2[gm] @m.x1.mp2[vgs] @m.x1.mp2[vds] @m.x1.mp2[vdsat]
echo "=== Stage1 NMOS mirror load ==="
print @m.x1.mn3[id] @m.x1.mn3[gm] @m.x1.mn3[vgs] @m.x1.mn3[vds] @m.x1.mn3[vdsat]
print @m.x1.mn4[id] @m.x1.mn4[gm] @m.x1.mn4[vgs] @m.x1.mn4[vds] @m.x1.mn4[vdsat]
echo "=== Stage2 ==="
print @m.x1.mn6[id] @m.x1.mn6[gm] @m.x1.mn6[vgs] @m.x1.mn6[vds] @m.x1.mn6[vdsat]
print @m.x1.mp6[id] @m.x1.mp6[gm] @m.x1.mp6[vgs] @m.x1.mp6[vds] @m.x1.mp6[vdsat]
echo "=== Saturation Margin ==="
let sat_mp1    = abs(@m.x1.mp1[vds])    - abs(@m.x1.mp1[vdsat])
let sat_mp2    = abs(@m.x1.mp2[vds])    - abs(@m.x1.mp2[vdsat])
let sat_mptail = abs(@m.x1.mptail[vds]) - abs(@m.x1.mptail[vdsat])
let sat_mn3    = abs(@m.x1.mn3[vds])    - abs(@m.x1.mn3[vdsat])
let sat_mn4    = abs(@m.x1.mn4[vds])    - abs(@m.x1.mn4[vdsat])
let sat_mn6    = abs(@m.x1.mn6[vds])    - abs(@m.x1.mn6[vdsat])
let sat_mp6    = abs(@m.x1.mp6[vds])    - abs(@m.x1.mp6[vdsat])
print sat_mp1 sat_mp2 sat_mptail sat_mn3 sat_mn4 sat_mn6 sat_mp6
quit
.endc
.end
