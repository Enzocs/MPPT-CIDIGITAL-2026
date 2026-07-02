`timescale 1ns/1ps

module tb_duty_controller;

    parameter width = 10;

    reg clk;
    reg rst;
    reg [1:0] Dc_in;
    wire [width:0] D_out;

    // Instância do DUT
    duty_controller #(width) DUT (
        .clk(clk),
        .rst(rst),
        .Dc_in(Dc_in),
        .D_out(D_out)
    );

    // Clock de 10 ns
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Monitor
    initial begin
        $display("Tempo\tRST\tDc_in\tD_out");
        $monitor("%0t\t%b\t%02b\t%0d",
                 $time, rst, Dc_in, D_out);
    end

    initial begin

        // Inicialização
        rst   = 1;
        Dc_in = 2'b10;     // manter

        #20;
        rst = 0;

        //----------------------------------------
        // Teste 1 - Incrementar
        //----------------------------------------
        $display("\n=== Incrementando ===");

        Dc_in = 2'b01;
      	repeat(10) @(posedge clk);
        // Esperado:
        // 200
        // 400
        // ...

        //----------------------------------------
        // Teste 2 - Manter
        //----------------------------------------
        $display("\n=== Mantendo ===");

        Dc_in = 2'b10;
      	repeat(10) @(posedge clk);

        //----------------------------------------
        // Teste 3 - Diminuir
        //----------------------------------------
        $display("\n=== Diminuindo ===");

        Dc_in = 2'b00;
      	repeat(10) @(posedge clk);
        // Esperado:
        // 800
        // 600
        // ...

        //----------------------------------------
        // Teste 4 - Saturação superior
        //----------------------------------------
        $display("\n=== Saturação Superior ===");

        Dc_in = 2'b01;
      	repeat(15) @(posedge clk);
        // Esperado:
        // ...
        // 1400
        // 1600
        // 1800
        // 2000
        // 2047 (MAX_D)

        //----------------------------------------
        // Teste 5 - Saturação inferior
        //----------------------------------------
        $display("\n=== Saturação Inferior ===");

        Dc_in = 2'b00;
      	repeat(20) @(posedge clk);
        // Esperado: nunca fica negativo

        //----------------------------------------
        // Teste 6 - Código inválido (11)
        //----------------------------------------
        $display("\n=== Código 11 ===");

        Dc_in = 2'b11;
      	repeat(8) @(posedge clk);
        // Esperado: mantém o valor

        $display("\nFim da simulação.");
        $finish;
		
      	/*
        	Obs.: O monitor vai "printar" a alteração da variável, portanto quando ela não muda não há repetição de print.
            ex.: 
            Tempo	RST		Dc_in	D_out
				0	1		10		0 
			   10	1		10		0 
			   20	1		10		0
        */
    end

endmodule