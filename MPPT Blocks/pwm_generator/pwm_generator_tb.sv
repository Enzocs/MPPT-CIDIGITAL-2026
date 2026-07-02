`timescale 1ns/1ps

module pwm_generator_tb;

    parameter width = 10;

    reg clk;
    reg rst;
    reg [width:0] D_in;
    wire pwm_out;

  pwm_generator #(.width(width)) dut (
        .clk(clk),
        .rst(rst),
        .D_in(D_in),
        .pwm_out(pwm_out)
    );

    // Clock de 100 MHz (10 ns)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin

        // Dump para Wave
        $dumpfile("pwm_generator_tb.vcd");
        $dumpvars(0, pwm_generator_tb);

        // Reset
        rst  = 1;
        D_in = 0;

        #50;
        rst = 0;

        // 0%
        $display("[%0t] Duty = 0%%", $time);
        D_in = 0;
        repeat (3000) @(posedge clk);

        // 25%
        $display("[%0t] Duty = 25%%", $time);
        D_in = 512;   // 512/2048
        repeat (3000) @(posedge clk);

        // 50%
        $display("[%0t] Duty = 50%%", $time);
        D_in = 1024;  // 1024/2048
        repeat (3000) @(posedge clk);

        // 75%
        $display("[%0t] Duty = 75%%", $time);
        D_in = 1536;  // 1536/2048
        repeat (3000) @(posedge clk);

        // 100%
        $display("[%0t] Duty = 100%%", $time);
        D_in = { (width+1){1'b1} }; // MAX_D = 2047
        repeat (3000) @(posedge clk);

        $display("Fim da simulacao.");
        $finish;
    end

endmodule