#!/bin/bash

# config sources.txt
cd hw
echo "hello_afu.json" > sources.txt
echo "rtl/generated/common.vhd" >> sources.txt
find rtl/generated/*.vhd ! -name "common.vhd" >> sources.txt
echo "rtl/lift_acc.vhd" >> sources.txt
echo "rtl/afu.sv" >> sources.txt
echo "rtl/ccip_interface_reg.sv" >> sources.txt
echo "rtl/ccip_std_afu.sv" >> sources.txt
cd ..
# build simulation
rm -rf build_sim
afu_sim_setup --source hw/sources.txt build_sim
cd build_sim
sed -i '1i SHELL:=/bin/bash' Makefile
make
# run simulation
make sim
