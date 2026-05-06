* ==================================================================
* Testbench B.DC_OP_10mA — Topology B (PMOS-input 5T + PMOS SF), DC OP
* ==================================================================

.lib '../../pdk/vpdk180nm/vpdk180nm_corners.lib' TT
.include './ldo_5t_pmos_in_sf.cir'

Vdd   vdd  0  DC 1.8
Vref  vref 0  DC 0.9
Ibias vdd  ibias DC 5u

Cload vout vout_cap 1u
Resr  vout_cap 0    5

Iload vout 0  DC 10m

X1 vdd 0 vout ibias vref vfb_node  ldo_5t_pmos_in_sf

.control
set noaskquit
op

echo "=== Node voltages ==="
print v(vout) v(x1.vbias_p) v(x1.ptail) v(x1.n1) v(x1.vea) v(x1.vg_pass) v(vfb_node)

echo "=== Bias chain sat margins ==="
let sm_Mbias    = abs(@m.x1.mbias[vds])    - abs(@m.x1.mbias[vdsat])
let sm_M_pbias_n = abs(@m.x1.m_pbias_n[vds]) - abs(@m.x1.m_pbias_n[vdsat])
let sm_M_pbias_p = abs(@m.x1.m_pbias_p[vds]) - abs(@m.x1.m_pbias_p[vdsat])
let sm_M_ptail  = abs(@m.x1.m_ptail[vds])  - abs(@m.x1.m_ptail[vdsat])
print sm_Mbias sm_M_pbias_n sm_M_pbias_p sm_M_ptail

echo "=== Stage-1 PMOS-input 5T sat margins ==="
let sm_M1 = abs(@m.x1.m1[vds]) - abs(@m.x1.m1[vdsat])
let sm_M2 = abs(@m.x1.m2[vds]) - abs(@m.x1.m2[vdsat])
let sm_M3 = abs(@m.x1.m3[vds]) - abs(@m.x1.m3[vdsat])
let sm_M4 = abs(@m.x1.m4[vds]) - abs(@m.x1.m4[vdsat])
print sm_M1 sm_M2 sm_M3 sm_M4

echo "=== PMOS SF buffer + pass sat margins ==="
let sm_M_buf_source = abs(@m.x1.m_buf_source[vds]) - abs(@m.x1.m_buf_source[vdsat])
let sm_Mbuf         = abs(@m.x1.mbuf[vds])         - abs(@m.x1.mbuf[vdsat])
let sm_MP_pass      = abs(@m.x1.mp_pass[vds])      - abs(@m.x1.mp_pass[vdsat])
print sm_M_buf_source sm_Mbuf sm_MP_pass

echo "=== Device currents ==="
print @m.x1.m_ptail[id] @m.x1.m_buf_source[id] @m.x1.mbuf[id] @m.x1.mp_pass[id]

echo "=== R-divider Ibleed verification ==="
let i_bleed_R1 = (v(vout) - v(vfb_node)) / 10k
let i_bleed_R2 = v(vfb_node) / 30k
print i_bleed_R1 i_bleed_R2

echo "=== Output regulation FOM ==="
let vout_err = abs(v(vout) - 1.2)
print vout_err

quit
.endc
.end
