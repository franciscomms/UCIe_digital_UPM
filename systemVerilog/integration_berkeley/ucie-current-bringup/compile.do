# Start Questa in the extracted ucie-current-bringup directory.
onerror {abort all}
if {![file exists modelsim.ini]} {vmap -c}
if {![file exists work_current_bringup]} {vlib work_current_bringup}
vmap work_current_bringup work_current_bringup
vlog -sv -mfcu -cuname current_bringup_cu -timescale 1ns/1ps -work work_current_bringup -f bringup.f
