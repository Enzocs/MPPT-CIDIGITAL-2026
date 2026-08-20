module sample_formatter_sva(

    input logic clk,
    input logic rst_n,

    input logic spi_data_valid,
    input logic sample_valid,

    input logic [15:0] v_sample_out,
    input logic [15:0] i_sample_out,

    input logic [1:0] current_state

);

    localparam STATE_IDLE         = 2'b00;
    localparam STATE_EXTEND_ALIGN = 2'b01;
    localparam STATE_CH_SEPARATOR = 2'b10;
    localparam STATE_REG_OUTPUT   = 2'b11;

    // ---------------------------------------------------------
    // Reset behavior
    // ---------------------------------------------------------
    property reset_outputs;
        @(posedge clk)
        !rst_n |-> (v_sample_out == 16'h0000 &&
                    i_sample_out == 16'h0000 &&
                    sample_valid == 1'b0 &&
                    current_state == STATE_IDLE);
    endproperty

    assert property(reset_outputs);

    // ---------------------------------------------------------
    // 3.10 sample_valid is one clock pulse
    // ---------------------------------------------------------
    property sample_valid_one_cycle;
        @(posedge clk)
        disable iff(!rst_n)
        sample_valid |=> !sample_valid;
    endproperty

    assert property(sample_valid_one_cycle);

    // ---------------------------------------------------------
    // 3.10 sample_valid only generated after a transaction
    // latency = 4 cycles after spi_data_valid
    // ---------------------------------------------------------
    property valid_after_transaction;
        @(posedge clk)
        disable iff(!rst_n)
        spi_data_valid |-> ##4 sample_valid;
    endproperty

    assert property(valid_after_transaction);

    // ---------------------------------------------------------
    // 3.11 FSM legal transitions
    // ---------------------------------------------------------
    property idle_to_extend;
        @(posedge clk)
        disable iff(!rst_n)
        (current_state == STATE_IDLE && spi_data_valid)
        |=> current_state == STATE_EXTEND_ALIGN;
    endproperty

    assert property(idle_to_extend);

    property extend_to_separator;
        @(posedge clk)
        disable iff(!rst_n)
        current_state == STATE_EXTEND_ALIGN
        |=> current_state == STATE_CH_SEPARATOR;
    endproperty

    assert property(extend_to_separator);

    property separator_to_output;
        @(posedge clk)
        disable iff(!rst_n)
        current_state == STATE_CH_SEPARATOR
        |=> current_state == STATE_REG_OUTPUT;
    endproperty

    assert property(separator_to_output);

    property output_to_idle;
        @(posedge clk)
        disable iff(!rst_n)
        current_state == STATE_REG_OUTPUT
        |=> current_state == STATE_IDLE;
    endproperty

    assert property(output_to_idle);

endmodule