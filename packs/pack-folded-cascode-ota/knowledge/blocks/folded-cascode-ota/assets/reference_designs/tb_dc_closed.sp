* DC Operating Point Testbench — DC closed-loop (Rfb + Cfb)
* Circuit: folded_cascode_ota (single-stage, 60-80 dB gain)
*
* ⭐ 推荐主用模板（与 tb_ac_gain_bw.sp 共用同一组激励）
*
* 设计意图（FC-OTA 60-80 dB 单级 high-gain 同样需要 closed-loop DC）:
*   - DC 与 AC 必须使用同一 testbench 激励：DC 工作点决定 small-signal 参数
*     (gm, gds, ro)，AC 测出来的 gain/PM 必须基于"AC 部署时实际收敛到的 OP"。
*   - high-gain 单级 OTA open-loop DC 不可靠：fold ratio mismatch / cascode bias
*     misalignment / 上下电流不匹配，被开环增益放大就让 vout 飘 rail。
*   - 本模板把 OP 拉回 Vcm 附近：Rfb=1G 让 fc≈0.16nHz (DC 等效短路)，
*     Cfb=1F 让 vinn 在 AC 路径上接地。
.lib '../../pdk/vpdk180nm/vpdk180nm_corners.lib' TT
.include './fc_ota.cir'

.param VDD   = 1.8
.param VCM   = 0.9
.param IBIAS = 10u
.param CLD   = 2p
.param RFB   = 1G          $ DC 闭环大电阻；不收敛时可降至 100Meg-10Meg 让 DC loop 更紧
.param CFB   = 1           $ Cfb=1F → AC 路径上 vinn 接地

VDD vdd 0 DC {VDD}
VSS vss 0 DC 0
IBIAS vdd ibias DC {IBIAS}

* DC closed-loop excitation (与 tb_ac_gain_bw.sp 共用)
Vcm  vcm  0   DC {VCM}
Vinp vinp vcm DC 0 AC 1
Rfb  vout vinn {RFB}
Cfb  vinn 0    {CFB}

X1 vinp vinn vout ibias vdd vss folded_cascode_ota

CL vout 0 {CLD}

.control
set noaskquit
op
print all
echo "=== Key Node Voltages (验 vinn ≈ Vcm 的 closed-loop 收敛) ==="
print v(vinp) v(vinn) v(vout)
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
echo "=== Saturation Margin (|vds| - |vdsat|, positive = saturated) ==="
let sat_mn1        = abs(@m.x1.mn1[vds])        - abs(@m.x1.mn1[vdsat])
let sat_mn2        = abs(@m.x1.mn2[vds])        - abs(@m.x1.mn2[vdsat])
let sat_mntail     = abs(@m.x1.mntail[vds])     - abs(@m.x1.mntail[vdsat])
let sat_mp1_bottom = abs(@m.x1.mp1_bottom[vds]) - abs(@m.x1.mp1_bottom[vdsat])
let sat_mp3_bottom = abs(@m.x1.mp3_bottom[vds]) - abs(@m.x1.mp3_bottom[vdsat])
let sat_mp2_top    = abs(@m.x1.mp2_top[vds])    - abs(@m.x1.mp2_top[vdsat])
let sat_mp4_top    = abs(@m.x1.mp4_top[vds])    - abs(@m.x1.mp4_top[vdsat])
let sat_mn5_bottom = abs(@m.x1.mn5_bottom[vds]) - abs(@m.x1.mn5_bottom[vdsat])
let sat_mn7_bottom = abs(@m.x1.mn7_bottom[vds]) - abs(@m.x1.mn7_bottom[vdsat])
let sat_mn6_top    = abs(@m.x1.mn6_top[vds])    - abs(@m.x1.mn6_top[vdsat])
let sat_mn8_top    = abs(@m.x1.mn8_top[vds])    - abs(@m.x1.mn8_top[vdsat])
print sat_mn1 sat_mn2 sat_mntail sat_mp1_bottom sat_mp3_bottom
print sat_mp2_top sat_mp4_top sat_mn5_bottom sat_mn7_bottom sat_mn6_top sat_mn8_top
quit
.endc
.end
