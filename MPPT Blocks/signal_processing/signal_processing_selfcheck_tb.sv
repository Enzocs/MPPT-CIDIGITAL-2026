/* 
*/

`timescale 1ns/1ps

module signal_processing_selfcheck_tb;

  /* Criação dos sinais */
    localparam WIDTH = 16;

    logic clk;
    logic rst_n;
    logic sample_valid;
    logic [WIDTH-1:0] v_sample_out;
    logic [WIDTH-1:0] i_sample_out;

    wire [WIDTH-1:0] v_signal_out;
    wire [WIDTH-1:0] i_signal_out;
    wire signal_valid;

  /* Instanciação do bloco */
    signal_processing dut (
        .clk(clk),
        .rst_n(rst_n),
        .sample_valid(sample_valid),
        .v_sample_out(v_sample_out),
        .i_sample_out(i_sample_out),
        .v_signal_out(v_signal_out),
        .i_signal_out(i_signal_out),
        .signal_valid(signal_valid)
    );

  /* Criação do clock */
    initial clk = 0;
    always #5 clk = ~clk;
  
  /* Criação de task para o modelo referência */
    logic [15:0] ref_v[0:3];
    logic [15:0] ref_i[0:3];

    logic [17:0] ref_v_sum;
    logic [17:0] ref_i_sum;

    logic [15:0] exp_v;
    logic [15:0] exp_i;

    task automatic push_sample(
        input logic [15:0] v,
        input logic [15:0] i
    );
     begin
        ref_v[3] = ref_v[2];
        ref_v[2] = ref_v[1];
        ref_v[1] = ref_v[0];
        ref_v[0] = v;

        ref_i[3] = ref_i[2];
        ref_i[2] = ref_i[1];
        ref_i[1] = ref_i[0];
        ref_i[0] = i;

        ref_v_sum = ref_v[0] + ref_v[1] + ref_v[2] + ref_v[3];
        ref_i_sum = ref_i[0] + ref_i[1] + ref_i[2] + ref_i[3];

        exp_v = ref_v_sum >> 2;
        exp_i = ref_i_sum >> 2;
     end
    endtask
  
  /* Reset inicial para o modelo de referência */
  task automatic reset_reference_model;
    integer j;
    begin
        for (j = 0; j < 4; j++) begin
            ref_v[j] = 16'h0000;
            ref_i[j] = 16'h0000;
        end
        ref_v_sum = 18'h00000;
        ref_i_sum = 18'h00000;
        exp_v     = 16'h0000;
        exp_i     = 16'h0000;
    end
  endtask
  
  /* Criação de task para envio de amostra */
      task automatic send_sample(
        input logic [15:0] v,
        input logic [15:0] i
    );
     begin
        @(posedge clk);
        v_sample_out <= v;
        i_sample_out <= i;
        sample_valid <= 1'b1;

        @(posedge clk);
        sample_valid <= 1'b0;

        push_sample(v,i);

        wait(signal_valid);

        if (v_signal_out !== exp_v || i_signal_out !== exp_i) begin
            $error("Mismatch: expected V=%0d I=%0d got V=%0d I=%0d",
                    exp_v, exp_i, v_signal_out, i_signal_out);
        end
        else begin
            $display("PASS: V=%0d I=%0d", v_signal_out, i_signal_out);
        end

        @(posedge clk);
     end
    endtask
  
  /* Binding das assertions */
  bind signal_processing signal_processing_sva sva_inst(
    .clk(clk),
    .rst_n(rst_n),
    .sample_valid(sample_valid),
    .signal_valid(signal_valid),
    .v_signal_out(v_signal_out),
    .i_signal_out(i_signal_out)
  );
  
  /* Rotina de testes */
    integer k;

    initial begin

        rst_n         = 0;
        sample_valid  = 0;
        v_sample_out  = 0;
        i_sample_out  = 0;

        repeat(5) @(posedge clk);
        rst_n = 1;
        reset_reference_model();

        // 3.2 Single sample
        $display("3.2 Single sample");
        send_sample(16'd100,16'd40);

        // 3.3 Pipeline filling
        $display("3.3 Pipeline filling");
        send_sample(16'd200,16'd80);
        send_sample(16'd300,16'd120);
        send_sample(16'd400,16'd160);

        // 3.4 Sliding window
        $display("3.4 Sliding window");
        send_sample(16'd500,16'd200);

        // 3.5 Constant inputs
        $display("3.5 Constant inputs");
        send_sample(16'd100,16'd100);
        send_sample(16'd100,16'd100);
        send_sample(16'd100,16'd100);
        send_sample(16'd100,16'd100);

        // 3.6 Increasing ramp
        $display("3.6 Increasing ramp");
        send_sample(16'd10,16'd10);
        send_sample(16'd20,16'd20);
        send_sample(16'd30,16'd30);
        send_sample(16'd40,16'd40);

        // 3.7 Decreasing ramp
        $display("3.7 Decreasing ramp");
        send_sample(16'd40,16'd40);
        send_sample(16'd30,16'd30);
        send_sample(16'd20,16'd20);
        send_sample(16'd10,16'd10);

        // 3.8 Maximum values
        $display("3.8 Maximum values");
        send_sample(16'hFFFF,16'hFFFF);
        send_sample(16'hFFFF,16'hFFFF);
        send_sample(16'hFFFF,16'hFFFF);
        send_sample(16'hFFFF,16'hFFFF);

        // 3.9 Minimum values
        $display("3.9 Minimum values");
        send_sample(16'd0,16'd0);
        send_sample(16'd0,16'd0);
        send_sample(16'd0,16'd0);
        send_sample(16'd0,16'd0);

        // 3.10 Random samples
        $display("3.10 Random samples");
        for(k=0;k<20;k++) begin
            send_sample($urandom,$urandom);
        end

        $display("ALL TESTS FINISHED");
        $finish;
    end

endmodule