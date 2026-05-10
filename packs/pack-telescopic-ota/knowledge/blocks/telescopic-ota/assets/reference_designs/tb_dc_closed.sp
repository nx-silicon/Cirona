* DC Operating Point Testbench — DC closed-loop (Rfb + Cfb)
* Circuit: telescopic_ota (single-stage, 60-80 dB gain)
*
* ⭐ 推荐主用模板（与 tb_ac_gain_bw.sp 共用同一组激励）
*
* 设计意图（Telescopic 60-80 dB 单级 high-gain，open-loop DC 不可靠）:
*   - DC 与 AC 必须使用同一 testbench 激励：DC 工作点决定 small-signal 参数
*     (gm, gds, ro)，AC 测出来的 gain/PM 必须基于"AC 部署时实际收敛到的 OP"。
*   - high-gain 单级 OTA open-loop DC 不可靠：cascode bias misalignment / wide-swing
*     mismatch / 上下电流不匹配，被开环增益放大就让 vout 飘 rail。
*   - 本模板把 OP 拉回 Vcm 附近：Rfb=1G 让 fc≈0.16nHz (DC 等效短路)，
*     Cfb=1F 让 vinn 在 AC 路径上接地。
*
* NOTE: Padding devices (MMbnc_bot, MMbpc_top) 仍预期 LINEAR region。
.lib '../../pdk/vpdk180nm/vpdk180nm_corners.lib' TT
.include './telescopic_ota.cir'

.param VDD   = 1.8
.param VCM   = 0.9
.param IBIAS = 10u
.param CLD   = 2p
.param RFB   = 1G          $ DC 闭环大电阻；不收敛时降至 100Meg-10Meg 让 DC loop 更紧
.param CFB   = 1           $ Cfb=1F → AC 路径上 vinn 接地

VDD vdd 0 DC {VDD}
VSS vss 0 DC 0
IBIAS vdd ibias DC {IBIAS}

* DC closed-loop excitation (与 tb_ac_gain_bw.sp 共用)
Vcm  vcm  0   DC {VCM}
Vinp vinp vcm DC 0 AC 1
Rfb  vout vinn {RFB}
Cfb  vinn 0    {CFB}

X1 vinp vinn vout ibias vdd vss telescopic_ota

CL vout 0 {CLD}

.control
set noaskquit
op
print all
echo "=== Key Node Voltages (验 vinn ≈ Vcm 的 closed-loop 收敛) ==="
print v(vinp) v(vinn) v(vout) v(vbnc) v(vbpc)
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
echo "=== Saturation Margin (gain-path devices, MUST be saturated) ==="
let sat_mm1     = abs(@m.x1.mm1[vds])     - abs(@m.x1.mm1[vdsat])
let sat_mm2     = abs(@m.x1.mm2[vds])     - abs(@m.x1.mm2[vdsat])
let sat_mmtail  = abs(@m.x1.mmtail[vds])  - abs(@m.x1.mmtail[vdsat])
let sat_mmcasc1 = abs(@m.x1.mmcasc1[vds]) - abs(@m.x1.mmcasc1[vdsat])
let sat_mmcasc2 = abs(@m.x1.mmcasc2[vds]) - abs(@m.x1.mmcasc2[vdsat])
let sat_mmcasp3 = abs(@m.x1.mmcasp3[vds]) - abs(@m.x1.mmcasp3[vdsat])
let sat_mmcasp4 = abs(@m.x1.mmcasp4[vds]) - abs(@m.x1.mmcasp4[vdsat])
let sat_mm3     = abs(@m.x1.mm3[vds])     - abs(@m.x1.mm3[vdsat])
let sat_mm4     = abs(@m.x1.mm4[vds])     - abs(@m.x1.mm4[vdsat])
print sat_mm1 sat_mm2 sat_mmtail sat_mmcasc1 sat_mmcasc2
print sat_mmcasp3 sat_mmcasp4 sat_mm3 sat_mm4
quit
.endc
.end
