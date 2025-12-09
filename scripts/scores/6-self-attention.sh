grep "Logic utilization" build_synth/build/output_files/afu_default.fit.summary
grep "Total RAM Blocks" build_synth/build/output_files/afu_default.fit.summary
grep "Total DSP Blocks" build_synth/build/output_files/afu_default.fit.summary
grep -E "required [0-9]+ cycles" real_run.log | awk '{print "GOP/s : " 313196544*2*0.2/$3}'
