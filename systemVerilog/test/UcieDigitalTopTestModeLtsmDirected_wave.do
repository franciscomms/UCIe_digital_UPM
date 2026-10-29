# QuestaSim waveform setup for UcieDigitalTopTestModeLtsmDirectedSpec_tb.
# From systemVerilog/test, after compiling sources.f into work:
#   vsim -voptargs=+acc UcieDigitalTopTestModeLtsmDirectedSpec_tb -do UcieDigitalTopTestModeLtsmDirected_wave.do
# In step ALL_ONES every signal in "TDR inputs" and in "LTSM inputs" is 1
# (except the clocks and ltsm cycles_1us, which has no TDR pin).
set tb /UcieDigitalTopTestModeLtsmDirectedSpec_tb
add wave -divider Control
add wave $tb/tb_step
add wave $tb/testModeLtsm
add wave $tb/reset_n
add wave $tb/clock
add wave -group {TDR inputs (jtagLtsm_*)} -ports -in $tb/dut/jtagLtsm_*
add wave -group {TDR outputs (jtagLtsm_*)} -ports -out $tb/dut/jtagLtsm_*
add wave -group {LTSM inputs (u_core.ltsm)} -ports -in $tb/dut/u_core/ltsm/*
add wave -group {LTSM outputs (u_core.ltsm)} -ports -out $tb/dut/u_core/ltsm/*
add wave -group {LTSM internal} $tb/dut/u_core/ltsm/stateReg
run -all
wave zoom full
