* DC Operating Point Testbench — DC closed-loop (Rfb + Cfb)
* Circuit: two_stage_ota_se
*
* ⭐ 推荐主用模板（与 tb_ac_gain_bw.sp 共用同一组激励）
*
* 设计意图（对 two-stage OTA 80-100dB 高增益运放至关重要）:
*   - DC 与 AC 必须使用同一 testbench 激励：DC 工作点决定 small-signal 参数
*     (gm, gds, ro)，AC 测出来的 gain/PM 必须基于"AC 部署时实际收敛到的 OP"。
*     如果 DC 用 open-loop (VINP=VINN 强制)、AC 用 closed-loop (Rfb shunt)，
*     两者 OP 不同 → AC 结果与实际部署状态无关，毫无意义。
*   - 高增益运放 open-loop DC 不可靠：stage1/stage2 mismatch 被开环增益放大，
*     即使数学上 VINP=VINN，数值精度 + device 参数 mismatch 让 vout 飘 rail。
*   - 本模板把 OP 拉回 Vcm 附近：Rfb=1G 让 fc≈0.16nHz (DC 等效短路)，
*     Cfb=1F 让 vinn 在 AC 路径上接地。
.lib '../../pdk/vpdk180nm/vpdk180nm_corners.lib' TT
.include './two_stage_ota.cir'

.param VDD   = 1.8
.param VCM   = 0.9
.param IBIAS = 10u
.param CLD   = 5p
.param RFB   = 1G          $ DC 闭环大电阻；高增益运放可改 10Meg 让 DC loop 更紧
.param CFB   = 1           $ Cfb=1F → AC 路径上 vinn 接地

* Supplies
VDD vdd 0 DC {VDD}
VSS vss 0 DC 0

* Ibias: sourced from VDD into the bias chain
IBIAS vdd ibias DC {IBIAS}

* DC closed-loop excitation (与 tb_ac_gain_bw.sp 共用)
* AC 注入位通过 Vinp 的 AC 1 标记；DC 模式下 AC=0 不影响
Vcm  vcm  0   DC {VCM}
Vinp vinp vcm DC 0 AC 1
Rfb  vout vinn {RFB}            $ DC: vout → vinn → 形成 unity-gain follower at DC
Cfb  vinn 0    {CFB}            $ AC: vinn 接地 (高频)，DC: 不导通

* DUT
X1 vinp vinn vout ibias vdd vss two_stage_ota_se

* Load capacitor
CL vout 0 {CLD}

.control
set noaskquit
op
print all
echo "=== Key Node Voltages ==="
print v(vinp) v(vinn) v(vout) v(vx) v(vx_l)
echo "=== Stage1 input pair ==="
print @m.x1.mp1[id] @m.x1.mp1[vgs] @m.x1.mp1[vds] @m.x1.mp1[vdsat]
print @m.x1.mp2[id] @m.x1.mp2[vgs] @m.x1.mp2[vds] @m.x1.mp2[vdsat]
print @m.x1.mptail[id] @m.x1.mptail[vgs] @m.x1.mptail[vds] @m.x1.mptail[vdsat]
echo "=== Stage1 NMOS mirror load ==="
print @m.x1.mn3[id] @m.x1.mn3[vgs] @m.x1.mn3[vds] @m.x1.mn3[vdsat]
print @m.x1.mn4[id] @m.x1.mn4[vgs] @m.x1.mn4[vds] @m.x1.mn4[vdsat]
echo "=== Stage2 ==="
print @m.x1.mn6[id] @m.x1.mn6[vgs] @m.x1.mn6[vds] @m.x1.mn6[vdsat]
print @m.x1.mp6[id] @m.x1.mp6[vgs] @m.x1.mp6[vds] @m.x1.mp6[vdsat]
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
