#!/bin/bash
cd build_sim
make sim
#LD_PRELOAD="/usr/lib/libopae-c-ase.so /usr/lib/libhugetlbfs.so" HUGETLB_MORECORE=yes HUGETLB_VERBOSE=99 make sim
