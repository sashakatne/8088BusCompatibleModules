# Run from the project root: do scripts/run.do
# (Or batch: vsim -c -do "do scripts/run.do; quit -f" | tee sim/transcript)
#
# All build artifacts (work/, *.ucdb, copied stimulus, dump.vcd) land in sim/.
# Source paths below are written relative to sim/ so they survive the cd.

# cd before vdel so that vdel -all targets sim/work/ (not a non-existent
# work/ in the parent directory). The catch absorbs vdel-19/-57 on a
# truly cold checkout where sim/work/ does not yet exist.
cd sim
catch {vdel -all}

vlib work

# Stimulus file: the encrypted Intel8088 IP reads busops.txt from cwd, so
# stage a fresh copy in sim/ at every run. Generated .mem files are expected
# to be in cwd as well; (re)generate them via:
#     python scripts/memfilegenerator.py
file copy -force ../stimulus/busops.txt .

vlog +acc -source -lint ../rtl/interface.sv

# === Pick ONE configuration below (the others are mutually exclusive) ===

# (1) Moore FSM driven by the encrypted Intel 8088 IP (default)
# vlog +acc -source -lint ../rtl/memorio.sv ../tb/top_interface.sv ../ip/8088if.svp

# (2) Moore FSM, self-checking testbench (no 8088 IP, prints *** PASSED ***)
# vlog +acc -source -lint ../rtl/memorio.sv ../tb/memorio_tb.sv

# (3) Mealy FSM driven by the encrypted Intel 8088 IP
# vlog +acc -source -lint ../rtl/memorio_mealy.sv ../tb/top_interface.sv ../ip/8088if.svp

# (4) Mealy FSM, self-checking testbench
vlog +acc -source -lint ../rtl/memorio_mealy.sv ../tb/memorio_tb.sv

# Simulation and coverage
vopt top -o top_optimized +acc +cover=sbfec+MemoryOrIOModule(rtl).
vsim top_optimized -coverage

set NoQuitOnFinish 1
onbreak {resume}
log /* -r
run -all

coverage save memorio.ucdb
vcover report memorio.ucdb
vcover report memorio.ucdb -cvg -details

add wave -position insertpoint sim:/top/*
add wave -position insertpoint sim:/top/bus/*

# Uncomment to expose individual module internals:
# add wave -position insertpoint sim:/top/M0/datapath/*
# add wave -position insertpoint sim:/top/M0/controlSequencer/*
# add wave -position insertpoint sim:/top/M1/datapath/*
# add wave -position insertpoint sim:/top/M1/controlSequencer/*
# add wave -position insertpoint sim:/top/IO0/controlSequencer/*
# add wave -position insertpoint sim:/top/IO0/datapath/*
# add wave -position insertpoint sim:/top/IO1/controlSequencer/*
# add wave -position insertpoint sim:/top/IO1/datapath/*
