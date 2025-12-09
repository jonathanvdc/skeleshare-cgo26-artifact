#!/bin/bash
cd sw
cmake .
make clean
make
LD_PRELOAD="/usr/lib64/libopae-c.so /usr/lib64/libhugetlbfs.so" HUGETLB_MORECORE=yes HUGETLB_VERBOSE=99 HUGETLB_SHARE=0 HUGETLB_NO_RESERVE=no ./hello_afu |& tee ../real_run.log
