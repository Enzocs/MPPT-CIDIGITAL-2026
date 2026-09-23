/*
	No 3.5 Ele gera um sinal de saída válida mas utilizando os valores passados (não atualiza as saídas, apenas sample_valid)
*/

`timescale 1ns/1ps

module sample_formatter_selfcheck_tb;

    localparam CLK_PERIOD = 10;

    // ---------------------------------------------------------
    // DUT Signals
    // ---------------------------------------------------------
    logic clk;
    logic rst_n;
    logic [15:0] spi_frame_rx;
    logic spi_data_valid;

    logic [15:0] v_sample_out;
    logic [15:0] i_sample_out;
    logic sample_valid;

    // ---------------------------------------------------------
    // DUT
    // ---------------------------------------------------------
    sample_formatter dut (
        .clk(clk),
        .rst_n(rst_n),
        .spi_frame_rx(spi_frame_rx),
        .spi_data_valid(spi_data_valid),
        .v_sample_out(v_sample_out),
        .i_sample_out(i_sample_out),
        .sample_valid(sample_valid)
    );

    // ---------------------------------------------------------
    // Clock
    // ---------------------------------------------------------
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // ---------------------------------------------------------
    // Send one SPI frame
    // ---------------------------------------------------------
    task automatic send_frame(
        input [3:0]  channel,
        input [11:0] sample
    );
    begin
        @(posedge clk);
        spi_frame_rx   <= {channel, sample};
        spi_data_valid <= 1'b1;

        @(posedge clk);
        spi_data_valid <= 1'b0;
    end
    endtask

    // ---------------------------------------------------------
    // Wait until sample_valid pulse
    // ---------------------------------------------------------
    task automatic wait_valid();
    begin
        while(sample_valid == 0)
            @(posedge clk);
        @(posedge clk);
    end
    endtask

    // ---------------------------------------------------------
    // Output checker
    // ---------------------------------------------------------
    task automatic check_outputs(
        input [15:0] exp_v,
        input [15:0] exp_i,
        input string test_name
    );
    begin
        if(v_sample_out !== exp_v || i_sample_out !== exp_i) begin
            $error("%s FAILED | V exp=%h got=%h | I exp=%h got=%h",
                    test_name,
                    exp_v, v_sample_out,
                    exp_i, i_sample_out);
        end
        else begin
            $display("%s PASSED", test_name);
        end
    end
    endtask


    // ---------------------------------------------------------
    // Random reference model
    // ---------------------------------------------------------
    reg [15:0] ref_v;
    reg [15:0] ref_i;

    integer k;
    reg [3:0] rand_channel;
    reg [11:0] rand_sample;

    // ---------------------------------------------------------
    // Binding das assertions 
    // ---------------------------------------------------------
    bind sample_formatter sample_formatter_sva formatter_sva_inst (
        .clk(clk),
        .rst_n(rst_n),
        .spi_data_valid(spi_data_valid),
        .sample_valid(sample_valid),
        .v_sample_out(v_sample_out),
        .i_sample_out(i_sample_out),
        .current_state(current_state)
    );

    // ---------------------------------------------------------
    // Main Test Sequence
    // ---------------------------------------------------------
    initial begin
      $dumpfile("dump.vcd");
      $dumpvars(0, sample_formatter_selfcheck_tb);

        ref_v = 0;
        ref_i = 0;

        rst_n          = 0;
        spi_frame_rx   = 0;
        spi_data_valid = 0;

        // =====================================================
        // Test 3.1 Reset
        // =====================================================
        repeat(3) @(posedge clk);
        rst_n = 1;
        @(posedge clk);
        repeat(3) @(posedge clk);
        rst_n = 0;
        @(posedge clk);
        repeat(3) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        check_outputs(16'h0000,16'h0000,"3.1 RESET");

        // =====================================================
        // Test 3.2 Voltage Formatting
        // =====================================================
        send_frame(4'h1,12'hABC);
        wait_valid();
        check_outputs(16'h0ABC,16'h0000,"3.2 VOLTAGE FORMAT");

        // =====================================================
        // Test 3.3 Current Formatting
        // =====================================================
        send_frame(4'h2,12'h123);
        wait_valid();
        check_outputs(16'h0ABC,16'h0123,"3.3 CURRENT FORMAT");

        // =====================================================
        // Test 3.4 Zero Extension
        // =====================================================
        send_frame(4'h1,12'hFFF);
        wait_valid();
        check_outputs(16'h0FFF,16'h0123,"3.4 ZERO EXTENSION");

        // =====================================================
        // Test 3.5 Invalid Channel
        // =====================================================
        send_frame(4'h5,12'h555);
        wait_valid();
        check_outputs(16'h0FFF,16'h0123,"3.5 INVALID CHANNEL");

        // =====================================================
        // Test 3.6 Minimum ADC
        // =====================================================
        send_frame(4'h1,12'h000);
        wait_valid();
        check_outputs(16'h0000,16'h0123,"3.6 MIN ADC");

        // =====================================================
        // Test 3.7 Maximum ADC
        // =====================================================
        send_frame(4'h2,12'hFFF);
        wait_valid();
        check_outputs(16'h0000,16'h0FFF,"3.7 MAX ADC");

        // =====================================================
        // Test 3.8 Consecutive Frames
        // =====================================================
        send_frame(4'h1,12'h001);
        wait_valid();

        send_frame(4'h2,12'h002);
        wait_valid();

        send_frame(4'h1,12'h003);
        wait_valid();

        send_frame(4'h2,12'h004);
        wait_valid();

        check_outputs(16'h0003,16'h0004,"3.8 CONSECUTIVE FRAMES");

        // =====================================================
        // Test 3.9 Random Frames
        // =====================================================
        ref_v = v_sample_out;
        ref_i = i_sample_out;

        for(k=0;k<50;k=k+1) begin

            rand_channel = $urandom_range(0,3);
            rand_sample  = $urandom_range(0,4095);

            send_frame(rand_channel,rand_sample);
            wait_valid();

            case(rand_channel)
                4'h1: ref_v = {4'h0,rand_sample};
                4'h2: ref_i = {4'h0,rand_sample};
                default: ;
            endcase

            if(v_sample_out !== ref_v || i_sample_out !== ref_i)
                $error("3.9 RANDOM FAILED iter=%0d ch=%h sample=%h",
                        k,rand_channel,rand_sample);

        end

        $display("3.9 RANDOM FRAMES PASSED");


        // =====================================================
        // Test 3.11 FSM State Transition
        // =====================================================
        send_frame(4'h1,12'h222);

        @(posedge clk);
        if(dut.current_state != dut.STATE_EXTEND_ALIGN)
            $error("FSM transition to EXTEND_ALIGN failed");

        @(posedge clk);
        if(dut.current_state != dut.STATE_CH_SEPARATOR)
            $error("FSM transition to CH_SEPARATOR failed");

        @(posedge clk);
        if(dut.current_state != dut.STATE_REG_OUTPUT)
            $error("FSM transition to REG_OUTPUT failed");

        @(posedge clk);
        if(dut.current_state != dut.STATE_IDLE)
            $error("FSM return to IDLE failed");

        $display("3.11 FSM TRANSITION PASSED");

        // =====================================================
        // Test 3.12 No Valid Input
        // =====================================================
        repeat(10) begin
            @(posedge clk);
            if(sample_valid)
                $error("3.12 FAILED | sample_valid asserted in idle");

            if(dut.current_state != dut.STATE_IDLE)
                $error("3.12 FAILED | FSM left IDLE unexpectedly");
        end

        $display("3.12 NO VALID INPUT PASSED");

        $display("========================================");
        $display("ALL TESTS COMPLETED");
        $display("========================================");

        $finish;

    end

endmodule