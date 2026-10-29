bind mppt_core mppt_core_monitor
#( .width(width))
monitor (
  .clk(clk),
  .rst(rst),
  .valid_signal(valid_signal),
  .V(V),
  .I(I),
  Dc_out(Dc_out),
  .valid_end_cycle(valid_end_cycle)
);
