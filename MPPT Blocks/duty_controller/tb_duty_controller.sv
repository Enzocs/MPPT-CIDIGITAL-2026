`timescale 1ns/1ps

module tb_duty_controller;

    parameter width = 10;

    reg clk;
    reg rst;
    reg valid_input;
    reg [1:0] Dc_in;
    wire [width:0] D_out;

    // Instância do DUT
    duty_controller #(width) DUT (
        .clk(clk),
        .rst(rst),
        .valid_input(valid_input),
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
        $display("Tempo\tRST\tVALID\tDc_in\tD_out");
        $monitor("%0t\t%b\t%b\t%02b\t%0d",
                 $time, rst, valid_input, Dc_in, D_out);
    end

    initial begin

        // Inicialização
        rst         = 1;
        valid_input = 1;
        Dc_in       = 2'b10;     // manter

        #20;
        rst = 0;

        //----------------------------------------
        // Teste 1 - Incrementar
        //----------------------------------------
        $display("\n=== Incrementando ===");

        valid_input = 1;
        Dc_in = 2'b01;
        repeat(10) @(posedge clk);

        //----------------------------------------
        // Teste 2 - Manter
        //----------------------------------------
        $display("\n=== Mantendo ===");

        valid_input = 1;
        Dc_in = 2'b10;
        repeat(10) @(posedge clk);

        //----------------------------------------
        // Teste 3 - Diminuir
        //----------------------------------------
        $display("\n=== Diminuindo ===");

        valid_input = 1;
        Dc_in = 2'b00;
        repeat(10) @(posedge clk);

        //----------------------------------------
        // Teste 4 - Saturação superior
        //----------------------------------------
        $display("\n=== Saturação Superior ===");

        valid_input = 1;
        Dc_in = 2'b01;
        repeat(15) @(posedge clk);

        //----------------------------------------
        // Teste 5 - Saturação inferior
        //----------------------------------------
        $display("\n=== Saturação Inferior ===");

        valid_input = 1;
        Dc_in = 2'b00;
        repeat(20) @(posedge clk);

        //----------------------------------------
        // Teste 6 - Código inválido (11)
        //----------------------------------------
        $display("\n=== Código 11 ===");

        valid_input = 1;
        Dc_in = 2'b11;
        repeat(8) @(posedge clk);

        //----------------------------------------
        // Teste 7 - valid_input = 0 (ignora Dc_in)
        //----------------------------------------
        $display("\n=== valid_input = 0 ===");

        valid_input = 0;
        Dc_in = 2'b01;      // deveria incrementar, mas deve ser ignorado
        repeat(5) @(posedge clk);

        Dc_in = 2'b00;      // deveria diminuir, mas deve ser ignorado
        repeat(5) @(posedge clk);

        Dc_in = 2'b11;      // também ignorado
        repeat(5) @(posedge clk);

        //----------------------------------------
        // Teste 8 - Retorna valid_input = 1
        //----------------------------------------
        $display("\n=== valid_input volta para 1 ===");

        valid_input = 1;
        Dc_in = 2'b01;
        repeat(5) @(posedge clk);

        $display("\nFim da simulação.");
        $finish;

        /*
        Obs.: O monitor só imprime quando algum sinal monitorado muda.
        Portanto, enquanto valid_input = 0 e D_out permanece constante,
        apenas as mudanças de Dc_in ou valid_input aparecerão no monitor.
        */
    end

endmodule
