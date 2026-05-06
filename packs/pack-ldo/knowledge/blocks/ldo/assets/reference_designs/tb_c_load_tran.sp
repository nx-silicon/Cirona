* ==================================================================
* Testbench A.LOAD_TRAN — Topology C, Iload step 1mA→10mA, slew 1µs
* ==================================================================

.lib '../../pdk/vpdk180nm/vpdk180nm_corners.lib' TT
.include './ldo_fc_buffer.cir'

Vdd   vdd  0  DC 1.8
Vref  vref 0  DC 0.9
Ibias vdd  ibias DC 5u

Cload vout vout_cap 1u
Resr  vout_cap 0    5

* PWL Iload: 1mA at t=0, step to 10mA at t=20µs (1µs ramp), back to 1mA at t=60µs
Iload vout 0 PWL(0 1m 20u 1m 21u 10m 60u 10m 61u 1m 100u 1m)

X1 vdd 0 vout ibias vref vfb_node ldo_fc_buffer

.tran 100n 100u

.control
set noaskquit
run

echo "=== Load Transient Results (1mA→10mA→1mA, 1µs slew) ==="

meas tran v_pre   find v(vout) at=15u
meas tran v_min   min  v(vout) from=20u to=40u
meas tran v_max   max  v(vout) from=60u to=80u
meas tran v_post  find v(vout) at=95u

print v_pre
print v_min
print v_max
print v_post

let undershoot_mV = (v_pre - v_min) * 1000
let overshoot_mV  = (v_max - v_post) * 1000
print undershoot_mV
print overshoot_mV

wrdata tb_c_load_tran.dat v(vout)

quit
.endc
.end
