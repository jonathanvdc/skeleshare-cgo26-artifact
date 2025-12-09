# ~/.profil executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
#umask 022

# if running bash
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
        . "$HOME/.bashrc"
    fi
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi

eval `ssh-agent`

# paths for FGPA stuff

#export XILINXD_LICENSE_FILE=27000@kensal.inf.ed.ac.uk
#export LM_LICENSE_FILE=27000@pamina.inf.ed.ac.uk
export LM_LICENSE_FILE=27003@localhost


echo export QUARTUS_HOME="/opt/intelFPGA_pro/quartus_19.2.0b57/quartus"
export QUARTUS_HOME="/opt/intelFPGA_pro/quartus_19.2.0b57/quartus"

echo export OPAE_PLATFORM_ROOT="/opt/inteldevstack/a10_gx_pac_ias_1_2_1_pv"
export OPAE_PLATFORM_ROOT="/opt/inteldevstack/a10_gx_pac_ias_1_2_1_pv"

echo export AOCL_BOARD_PACKAGE_ROOT="/opt/inteldevstack/a10_gx_pac_ias_1_2_1_pv/opencl/opencl_bsp"
export AOCL_BOARD_PACKAGE_ROOT="/opt/inteldevstack/a10_gx_pac_ias_1_2_1_pv/opencl/opencl_bsp"
if ls /dev/intel-fpga-* 1> /dev/null 2>&1; then
echo sudo $AOCL_BOARD_PACKAGE_ROOT/linux64/libexec/setup_permissions.sh
sudo $AOCL_BOARD_PACKAGE_ROOT/linux64/libexec/setup_permissions.sh
fi
OPAE_PLATFORM_BIN="/opt/inteldevstack/a10_gx_pac_ias_1_2_1_pv/bin"
if [[ ":${PATH}:" = *":${OPAE_PLATFORM_BIN}:"* ]] ;then
    echo "\$OPAE_PLATFORM_ROOT/bin is in PATH already"
else
    echo "Adding \$OPAE_PLATFORM_ROOT/bin to PATH"
    export PATH="${PATH}":"${OPAE_PLATFORM_BIN}"
fi

echo export INTELFPGAOCLSDKROOT="/opt/intelFPGA_pro/quartus_19.2.0b57/hld"
export INTELFPGAOCLSDKROOT="/opt/intelFPGA_pro/quartus_19.2.0b57/hld"
echo export ALTERAOCLSDKROOT=$INTELFPGAOCLSDKROOT
export ALTERAOCLSDKROOT=$INTELFPGAOCLSDKROOT

QUARTUS_BIN="/opt/intelFPGA_pro/quartus_19.2.0b57/quartus/bin"
if [[ ":${PATH}:" = *":${QUARTUS_BIN}:"* ]] ;then
    echo "\$QUARTUS_HOME/bin is in PATH already"
else
    echo "Adding \$QUARTUS_HOME/bin to PATH"
    export PATH="${QUARTUS_BIN}":"${PATH}"
fi
echo source $INTELFPGAOCLSDKROOT/init_opencl.sh
source $INTELFPGAOCLSDKROOT/init_opencl.sh >> /dev/null

export QSYS_ROOTDIR="/opt/intelFPGA_pro/quartus_19.2.0b57/qsys/bin"

#export MTI_HOME="/opt/intelFPGA_pro/18.1/modelsim_ae"
export MTI_HOME="/opt/intelFPGA_pro/18.1/modelsim_ase"
export QUESTA_HOME="/opt/intelFPGA_pro/18.1/modelsim_ase"
export FPGA_BBB_CCI_SRC="/opt/intelFPGA_pro/intel-fpga-bbb"
#export OPAE_BASEDIR="/opt/intelFPGA_pro/opae-sdk"

export PATH="/opt/bwtk/2018.6L/bin/:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin:$HOME/.local/bin:$PATH"
#export PATH="/opt/intelFPGA_pro/18.1/modelsim_ae/linuxaloem/:$PATH"
#export PATH="/opt/intelFPGA_pro/18.1/modelsim_ase/linuxaloem/:$PATH"
export PATH="/opt/intelFPGA_pro/18.1/modelsim_ase/bin:$PATH"

export OPAE_PLATFORM_ROOT="/opt/inteldevstack/a10_gx_pac_ias_1_2_1_pv"
export DCP_LOC="/opt/inteldevstack/a10_gx_pac_ias_1_2_1_pv"
export SHELL="/bin/bash"
export PATH="${PATH}":"${OPAE_PLATFORM_BIN}"
export PATH="${PATH}":"${OPAE_PLATFORM_ROOT}"
export OPAE_BASEDIR="/opt/inteldevstack/opae-sdk-1.4.0-1"
export INC_PATH="/opt/inteldevstack/a10_gx_pac_ias_1_2_1_pv/include"
export LIB_PATH="/opt/inteldevstack/a10_gx_pac_ias_1_2_1_pv/lib"
#export LD_LIBRARY_PATH="${LIB_PATH}":"${LD_LIBRARY_PATH}"
export LD_LIBRARY_PATH="/usr/local/lib64:"${LD_LIBRARY_PATH}
source /opt/intelFPGA_pro/quartus_19.2.0b57/hld/init_opencl.sh
