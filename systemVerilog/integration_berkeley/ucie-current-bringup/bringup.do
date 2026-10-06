# Current UPM implementation versus unpatched Berkeley: stop at first error.
onerror {abort all}
do compile.do
vsim -t 1ps -voptargs=+acc work_current_bringup.UcieSerialBringUp_tb work_current_bringup.current_bringup_cu +STOP_ON_ERROR=1
add wave sim:/UcieSerialBringUp_tb/*
add wave sim:/UcieSerialBringUp_tb/upm_die/dut/sb_msg_*
add wave sim:/UcieSerialBringUp_tb/upm_die/dut/sideband/rx/validReg
add wave sim:/UcieSerialBringUp_tb/upm_die/dut/linkMgmtLtsm/ltsm/stateReg
run -all
