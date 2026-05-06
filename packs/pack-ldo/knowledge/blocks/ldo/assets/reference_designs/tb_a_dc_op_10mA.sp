* ==================================================================
* Testbench A.DC_OP_10mA — Topology A (5T+PMOS-CS), DC operating point
* ==================================================================
* Verifies all devices saturated at nominal Iload=10mA, Vout=1.2V.
* Vfb is internal (driven by R1+R2 divider); testbench leaves vfb dangling.
* ==================================================================

.lib '../../pdk/vpdk180nm/vpdk180nm_corners.lib' TT
.include './ldo_5t_pmos_cs.cir'

Vdd   vdd  0  DC 1.8
Vref  vref 0  DC 0.9
Ibias vdd  ibias  DC 5u

* External output cap: 1µF + 5Ω ESR (typical for ext-cap LDO)
Cload vout vout_cap  1u
Resr  vout_cap  0    5

* Test load
Iload vout 0  DC 10m

* LDO instance — 6 ports, vfb_node not connected externally (driven by internal divider)
X1 vdd 0 vout ibias vref vfb_node  ldo_5t_pmos_cs

.control
set noaskquit
op

echo "=== Node voltages ==="
print v(vout) v(x1.vea_left) v(x1.v1) v(x1.vg_pass) v(vfb_node) v(x1.ntail)

echo "=== Supply currents ==="
print i(Vdd) i(Vref) i(Ibias) i(Iload)

echo "=== Stage-1 5T-OTA sat margins (Vds-Vdsat) ==="
let sm_M1 = abs(@m.x1.m1[vds]) - abs(@m.x1.m1[vdsat])
let sm_M2 = abs(@m.x1.m2[vds]) - abs(@m.x1.m2[vdsat])
let sm_M3 = abs(@m.x1.m3[vds]) - abs(@m.x1.m3[vdsat])
let sm_M4 = abs(@m.x1.m4[vds]) - abs(@m.x1.m4[vdsat])
let sm_M5 = abs(@m.x1.m5[vds]) - abs(@m.x1.m5[vdsat])
print sm_M1 sm_M2 sm_M3 sm_M4 sm_M5

echo "=== Stage-2 + pass + bias sat margins ==="
let sm_MP_cs   = abs(@m.x1.mp_cs[vds])   - abs(@m.x1.mp_cs[vdsat])
let sm_MN_sink = abs(@m.x1.mn_sink[vds]) - abs(@m.x1.mn_sink[vdsat])
let sm_MP_pass = abs(@m.x1.mp_pass[vds]) - abs(@m.x1.mp_pass[vdsat])
let sm_Mbias   = abs(@m.x1.mbias[vds])   - abs(@m.x1.mbias[vdsat])
print sm_MP_cs sm_MN_sink sm_MP_pass sm_Mbias

echo "=== Device currents ==="
print @m.x1.m5[id] @m.x1.mp_cs[id] @m.x1.mn_sink[id] @m.x1.mp_pass[id]

echo "=== R-divider Ibleed verification ==="
let i_bleed_R1 = (v(vout) - v(vfb_node)) / 10k
let i_bleed_R2 = v(vfb_node) / 30k
print i_bleed_R1 i_bleed_R2

echo "=== Output regulation FOM ==="
let vout_err = abs(v(vout) - 1.2)
let iq_total = abs(i(Vdd)) - 10m
print vout_err iq_total

quit
.endc
.end
