`timescale 1ns/1ps

module mppt_core_tb;

    parameter width = 10;

    reg clk;
    reg rst;
    reg valid_signal;
    reg [width-1:0] V;
    reg [width-1:0] I;

    wire [1:0] Dc_out;
  	wire valid_end_cycle;

    //====================================================
    // Instância do DUT
    //====================================================

    mppt_core #(width) dut (
        .clk(clk),
        .rst(rst),
        .valid_signal(valid_signal),
        .V(V),
        .I(I),
        .Dc_out(Dc_out),
        .valid_end_cycle(valid_end_cycle)
    );

    //====================================================
    // Clock de 100 MHz
    //====================================================

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    //====================================================
    // Tarefa para gerar um pulso de valid
    //====================================================

    task send_sample;
        input [width-1:0] v_in;
        input [width-1:0] i_in;
        begin
            @(negedge clk);
            V = v_in;
            I = i_in;
            valid_signal = 1'b1;

            @(negedge clk);
            valid_signal = 1'b0;
        end
    endtask

    //====================================================
    // Monitor
    //====================================================

    initial begin
        $display("------------------------------------------------------------------------------------");
      $display("Tempo\tState\tValid\tV\tI\tP\tV_old\tP_old\tVref\tDc\tValid_end_cycle");
        $display("------------------------------------------------------------------------------------");

      $monitor("%0t\t%d\t%b\t%d\t%d\t%d\t%d\t%d\t%d\t%b\t%b",
                 $time,
                 dut.state,
                 valid_signal,
                 V,
                 I,
                 dut.P_newer,
                 dut.V_older,
                 dut.P_older,
                 dut.V_ref_older,
                 Dc_out,
	             valid_end_cycle);
    end

    //====================================================
    // Estímulos
    //====================================================

    initial begin

        rst = 1'b1;
        valid_signal = 1'b0;
        V = 0;
        I = 0;

        repeat(2) @(posedge clk);
        rst = 1'b0;

        //------------------------------------------------
        // Caso 1
        // P aumenta
        //------------------------------------------------
        $display("\nCaso 1: P aumenta");
        send_sample(100,5);      // P=500
        repeat(8) @(posedge clk);

        //------------------------------------------------
        // Caso 2
        // P aumenta novamente
        //------------------------------------------------
        $display("\nCaso 2: P aumenta novamente");
        send_sample(120,5);      // P=600
        repeat(8) @(posedge clk);

        //------------------------------------------------
        // Caso 3
        // P diminui
        //------------------------------------------------
        $display("\nCaso 3: P diminui");
        send_sample(110,3);      // P=330
        repeat(8) @(posedge clk);

        //------------------------------------------------
        // Caso 4
        // P aumenta e V diminui
        //------------------------------------------------
        $display("\nCaso 4: P aumenta e V diminui");
        send_sample(90,8);       // P=720
        repeat(8) @(posedge clk);

        //------------------------------------------------
        // Caso 5
        // Potência igual
        //------------------------------------------------
        $display("\nCaso 5: Potência igual");
        send_sample(90,8);       // P=720
        repeat(8) @(posedge clk);

        //------------------------------------------------
        // Caso 6
        // Outra potência
        //------------------------------------------------
        $display("\nCaso 6: Novo ponto");
        send_sample(80,4);       // P=320
        repeat(8) @(posedge clk);

        //------------------------------------------------

        $display("\nFim da simulacao.");
        $finish;

    end

endmodule