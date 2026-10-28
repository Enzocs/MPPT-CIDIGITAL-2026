create_clock -name clock -period 10 [get_ports clk]
set_clock_uncertainty 2 [get_clocks clock]
set_clock_latency 1 [get_clocks clock]
set_ideal_net [get_nets clk]
set_ideal_net [get_nets rst]
set_load -pin_load 0.100 [get_ports [all_outputs]]

