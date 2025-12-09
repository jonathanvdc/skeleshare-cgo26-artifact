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
# build hw
rm -rf build_synth
afu_synth_setup --source hw/sources.txt build_synth
cd build_synth
${OPAE_PLATFORM_ROOT}/bin/run.sh
PACSign PR -t UPDATE -H openssl_manager -i hello_afu.gbs -o hello_afu_unsigned_ssl.gbs -y
