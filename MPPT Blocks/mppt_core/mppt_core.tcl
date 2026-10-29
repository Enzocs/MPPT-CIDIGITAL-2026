clear -all

set_parallel_synthesis_num_process 2

analyze -sv09 -f_relative_to_file_location <PATH_TO_FILELIST>/mppt_filelist.f

analyze -sv09 <PATH>/mppt_core_monitor.sv <PATH>/mppt_core_bind.sv

 

set_loop_handling assume_stable

 

puts "Coverage enabled, initializing coverage"

check_cov -init -model {all} -type {coi proof stimuli} -proof_core_include_failing -exclude_bind_hierarchies -covdut mppt_core

 

# Elaborate design and properties, add parameters

# -disable_auto_bbox: without it, Jasper auto-blackboxes the V*I multiplier

# (default blackbox threshold is 1 bit) in both the DUT and the monitor,

# turning power comparisons into free/unconstrained values and producing

# spurious counterexamples on every property that depends on P_newer.

elaborate -top mppt_core -disable_auto_bbox -parameter width 4 -create_related_covers {precondition infinite_precondition witness}

clock clk

reset -expression { rst }

 

check_cov -waiver -add -source_file <PATH>/mppt_core.sv -start_line 169 -end_line 172 -start_column 16 -end_column 10 -expression {~|{(state == 3'b0), (state == 3'b1), (state == 3'b10), (state == 3'b11), (state == 3'b100), (state == 3'b101), (state == 3'b110)}} -persistency AAABanicTZBLDsIwDEQHxAm4ALBj2aYlbVlxE9S0KULiJwT359mwIJGd8W9sR9JC0kG1KmVNSopqFHhbleo1gGrQjthEZEQy8Yy3wCp4d1xpqase3JeOVN31JMeYJ6ItmR2V/e+tHSV6dt65hGfA0xNrsEZqBizLNY4GloKuNlH5m8cmjPiDT1HCksAR1PoelWdnMivn6PBGcIPufKsMTs5tyDoW1FqlbRXQER28T4BjjmyQGbLS92y1/ruj/2Gvty78wx5PwnPSWbcPZVUtlQ== -type branch -top -comment default -tag *

check_cov -waiver -add -source_file <PATH>/mppt_core.sv -start_line 126 -end_line 126 -start_column 9 -end_column 27 -expression {~|{(state == 3'b0), (state == 3'b1), (state == 3'b10), (state == 3'b11), (state == 3'b100), (state == 3'b101), (state == 3'b110)}} -persistency AAABdnicrZBLDsIwDERHwAk4AUdIf2krhMQCFkjcASWtu+MjYMHxeYm6Yk2siR2PPU4iaSVpr1qVTJOivFqV+E6FggaimqiBm2BGYPBG1nFy+AaT1rrqgb11oeuuJzVJOfV1KHm6HPAoluQCSkE9ZnlCmu7wY54T8aky/k2j4pYFlU2OjDu2mSuJKrp6atOUCGfzmyO7z28e0FjOWMxIq9bmx250f/IvvNgDMLI7cNJBZx21/QLuYjDn -type statement -top -comment default -tag *

check_cov -waiver -add -source_file <PATH>/mppt_core.sv -start_line 170 -end_line 170 -start_column 9 -end_column 24 -expression {~|{(state == 3'b0), (state == 3'b1), (state == 3'b10), (state == 3'b11), (state == 3'b100), (state == 3'b101), (state == 3'b110)}} -persistency AAABcHicrY9BCsIwEEW/4gk8gTt3Mmna2iKCC+9R0rTZiSIKHt+X0JVr8xlmJn/mhUjaSLqoltespFGtjqrInZyCIlVN1eAlnImY8Wdujc7IDZK2uumBXhrYuuvJTCb3bEToLTSDEcmeqkWJzQlaUyJwY+XNHuWX/R8ZI13HtJW/5H9OeKHISu2491QBN+E7ZFBrNh2M9RKrJfI5aPejK9MDjLc+dGei0h5iZp2+JwQuZA== -type statement -top -comment default -tag *

check_cov -waiver -add -source_file <PATH>/mppt_core.sv -start_line 171 -end_line 171 -start_column 5 -end_column 32 -expression {~|{(state == 3'b0), (state == 3'b1), (state == 3'b10), (state == 3'b11), (state == 3'b100), (state == 3'b101), (state == 3'b110)}} -persistency AAABgHicrY9dCsIwEIRH8QSewDdfmzSNLaJ4k9K0KQj1B1HR2/ul5Ah2mexmZ3a2kbSSdJJTqahRQV47WXIto049laOq4EaYAUT4SLfgVpArQlrrojvxVMvUTQ80yXmcNRZ/y2xgpmOHAZ6qAQ5Nj4fnjOwN6GpuDtb80WOgk14W0A1wacLjXM91Q7/ML0xMckwbLIizxzJjkZG+ozY53vzFpDPzLfrrnHt9wcS9hX3pg+4AjLZsM9r/APKRMl0= -type statement -top -comment default -tag *

check_cov -waiver -add -source_file <PATH>/mppt_core.sv -start_line 125 -end_line 127 -start_column 16 -end_column 10 -expression {~|{(state == 3'b0), (state == 3'b1), (state == 3'b10), (state == 3'b11), (state == 3'b100), (state == 3'b101), (state == 3'b110)}} -persistency AAABanicTZBLDsIwDERHiBPABWDHst+0ZcVNUJKmCImfENyfF7cLYkV2ZuzJJJLWkk5qVCtpUpBTp4rcq5RXpGqoWrgJZmQn+ARacCrILSFtdNeL+OjM1FNverLyBNvTOTDpl9xYFbhzsJtLdCKIh+s4jcxETrk3a3SoFNyaHZWLn+zQgVfmokQlUDuq3t5RW3eis158OENmJpGzejB3+TXR3GRfI7wjElhEu2d7NFbsvea1XfJBu78Y7Q+9vrrxD0eQAHLRVY8fy6guxA== -type branch -top -comment default -tag *

