bind duty_controller duty_controller_monitor
    #(
        .width(width)
    ) monitor (
        .clk(clk),
        .rst(rst),
        .valid_input(valid_input),
        .Dc_in(Dc_in),
        .D_out(D_out)
    );
