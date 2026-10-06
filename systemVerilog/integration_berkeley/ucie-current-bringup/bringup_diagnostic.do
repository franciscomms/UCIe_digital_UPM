# Same hardware: collect later errors until the bounded SBINIT watchdog.
# All errors remain failures; this mode never turns a failure into PASS.
onerror {abort all}
do compile.do
vsim -t 1ps -voptargs=+acc work_current_bringup.UcieSerialBringUp_tb work_current_bringup.current_bringup_cu +STOP_ON_ERROR=0 +MAX_SBINIT=20000
add wave sim:/UcieSerialBringUp_tb/*
add wave sim:/UcieSerialBringUp_tb/upm_die/dut/sb_msg_*
run -all
