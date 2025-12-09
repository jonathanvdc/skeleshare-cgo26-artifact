#!/bin/bash
export ASE_WORKDIR=$(pwd)/build_sim/work
cd sw
cmake ..
make clean
make
./hello_afu
#LD_PRELOAD="/usr/lib/libopae-c-ase.so" ./hello_afu
#LD_PRELOAD="/usr/lib/libopae-c-ase.so /usr/lib/libhugetlbfs.so" HUGETLB_MORECORE=yes HUGETLB_VERBOSE=99 ./hello_afu
