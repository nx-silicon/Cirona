* ==================================================================
* PSRR — PNP bandgap
* Purpose: measure Vref supply rejection from 1 Hz to 10 MHz.
*   PSRR(f) [dB] = −20·log10( |vref(f)| / |vdd(f)| ) = −vdb(vref)
* DC supply is 1.8 V; AC perturbation of 1 V applied to VDD pin.
* ==================================================================

.lib '../../pdk/vpdk180nm/vpdk180nm_corners.lib' TT
.include './bandgap.cir'

VDD vdd 0 DC 1.8 AC 1
VSS vss 0 0
Xdut vdd vss vref bandgap

.control
set noaskquit
set units = degrees
ac dec 10 1 10Meg
setplot ac1

let psrr_db = -vdb(vref)

meas ac psrr_dc      find psrr_db at=1
meas ac psrr_100hz   find psrr_db at=100
meas ac psrr_1khz    find psrr_db at=1k
meas ac psrr_10khz   find psrr_db at=10k
meas ac psrr_100khz  find psrr_db at=100k
meas ac psrr_1mhz    find psrr_db at=1Meg
meas ac psrr_10mhz   find psrr_db at=10Meg

echo "=== PSRR vs frequency ==="
print psrr_dc psrr_100hz psrr_1khz psrr_10khz psrr_100khz psrr_1mhz psrr_10mhz

wrdata bandgap_psrr.dat psrr_db
quit
.endc

.end
