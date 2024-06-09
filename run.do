vdel -all

vlib work

vlog +acc -source -lint interface.sv
# Interface simulation for Moore FSM
vlog +acc -source -lint memorio.sv top_interface.sv 8088if.svp

# Extra Credit

# Self-checking and Interface
# vlog +acc -source -lint memorio.sv memorio_tb.sv

# Interface simulation for Mealy FSM
# vlog +acc -source -lint memorio_mealy.sv top_interface.sv 8088if.svp
# Self-checking and Interface
# vlog +acc -source -lint memorio_mealy.sv memorio_tb.sv

# Simulation and waveforms
vopt top -o top_optimized +acc +cover=sbfec+MemoryOrIOModule(rtl).
vsim top_optimized -coverage

# vsim -voptargs=+acc work.top

set NoQuitOnFinish 1
onbreak {resume}
log /* -r
run -all

coverage save memorio.ucdb
vcover report memorio.ucdb
vcover report memorio.ucdb -cvg -details

add wave -position insertpoint sim:/top/*
add wave -position insertpoint sim:/top/bus/*

# Uncomment the following lines to add waveforms for the individual modules

# add wave -position insertpoint sim:/top/M0/datapath/*
# add wave -position insertpoint sim:/top/M0/controlSequencer/*
# add wave -position insertpoint sim:/top/M1/datapath/*
# add wave -position insertpoint sim:/top/M1/controlSequencer/*
# add wave -position insertpoint sim:/top/IO0/controlSequencer/*
# add wave -position insertpoint sim:/top/IO0/datapath/*
# add wave -position insertpoint sim:/top/IO1/controlSequencer/*
# add wave -position insertpoint sim:/top/IO1/datapath/*

# run -all
