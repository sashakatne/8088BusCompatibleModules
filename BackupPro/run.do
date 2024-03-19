vlib work

# Interface
vlog +acc -source -lint memorio_moore_interface.sv top_interface_moore.sv 8088if.svp

# Self-checking and Interface
# vlog +acc -source -lint memorio_moore_interface.sv memorio_tb_interface.sv

# Simulation and waveforms
vsim -voptargs=+acc work.top

add wave -position insertpoint sim:/top/*
add wave -position insertpoint sim:/top/bus/*

#add wave -position insertpoint sim:/top/M0/datapath/*
#add wave -position insertpoint sim:/top/M0/controlSequencer/*
#add wave -position insertpoint sim:/top/M1/datapath/*
#add wave -position insertpoint sim:/top/M1/controlSequencer/*
#add wave -position insertpoint sim:/top/IO0/controlSequencer/*
#add wave -position insertpoint sim:/top/IO0/datapath/*
#add wave -position insertpoint sim:/top/IO1/controlSequencer/*
#add wave -position insertpoint sim:/top/IO1/datapath/*

#add wave -position insertpoint sim:/top/memory0/*
#add wave -position insertpoint sim:/top/memory1/*
#add wave -position insertpoint sim:/top/io_device0/*
#add wave -position insertpoint sim:/top/io_device1/*

run -all