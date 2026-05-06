* ==================================================================
* Testbench C.DC_OP_10mA — Topology C (FC + direct + Ahuja dual-cap)
* ==================================================================

.lib '../../pdk/vpdk180nm/vpdk180nm_corners.lib' TT
.include './ldo_fc_buffer.cir'

Vdd   vdd  0  DC 1.8
Vref  vref 0  DC 0.9
Ibias vdd  ibias DC 5u

Cload vout vout_cap 1u
Resr  vout_cap 0    5

Iload vout 0  DC 10m

X1 vdd 0 vout ibias vref vfb_node  ldo_fc_buffer

.control
set noaskquit
op

echo "=== Node voltages ==="
print v(vout) v(x1.vbias_fold) v(x1.vbc_p) v(x1.vbc_n) v(x1.vea) v(x1.ntail) v(vfb_node)

echo "=== FC EA core sat margins ==="
let sm_MN1     = abs(@m.x1.mn1[vds])     - abs(@m.x1.mn1[vdsat])
let sm_MN2     = abs(@m.x1.mn2[vds])     - abs(@m.x1.mn2[vdsat])
let sm_MN_tail = abs(@m.x1.mn_tail[vds]) - abs(@m.x1.mn_tail[vdsat])
let sm_MP_fL   = abs(@m.x1.mp_fold_l[vds]) - abs(@m.x1.mp_fold_l[vdsat])
let sm_MP_fR   = abs(@m.x1.mp_fold_r[vds]) - abs(@m.x1.mp_fold_r[vdsat])
print sm_MN1 sm_MN2 sm_MN_tail sm_MP_fL sm_MP_fR

echo "=== Cascode + mirror sat margins ==="
let sm_MP_pcL  = abs(@m.x1.mp_pcas_l[vds]) - abs(@m.x1.mp_pcas_l[vdsat])
let sm_MP_pcR  = abs(@m.x1.mp_pcas_r[vds]) - abs(@m.x1.mp_pcas_r[vdsat])
let sm_MN_ncL  = abs(@m.x1.mn_ncas_l[vds]) - abs(@m.x1.mn_ncas_l[vdsat])
let sm_MN_ncR  = abs(@m.x1.mn_ncas_r[vds]) - abs(@m.x1.mn_ncas_r[vdsat])
let sm_MN_mL   = abs(@m.x1.mn_mir_l[vds])  - abs(@m.x1.mn_mir_l[vdsat])
let sm_MN_mR   = abs(@m.x1.mn_mir_r[vds])  - abs(@m.x1.mn_mir_r[vdsat])
print sm_MP_pcL sm_MP_pcR sm_MN_ncL sm_MN_ncR sm_MN_mL sm_MN_mR

echo "=== Pass FET ==="
let sm_MP_pass = abs(@m.x1.mp_pass[vds]) - abs(@m.x1.mp_pass[vdsat])
print sm_MP_pass

echo "=== Device currents ==="
print @m.x1.mn_tail[id] @m.x1.mp_fold_l[id] @m.x1.mp_pass[id]

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
