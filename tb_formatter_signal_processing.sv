`timescale 1ns / 1ps

module tb_mppt_signal_chain;

    // 1. Sinais Globais
    reg clk;
    reg rst_n;

    // 2. Conexões Intermediárias (Formatter -> Processing)
    reg  [11:0] spi_data_rx;
    reg         spi_channel_id;
    reg         spi_data_valid;

    wire [15:0] v_sample_out;
    wire [15:0] i_sample_out;
    wire        sample_valid;

    // 3. Saídas Finais (Signal Processing)
    wire [15:0] v_signal_out;
    wire [15:0] i_signal_out;
    wire        signal_valid;

    // 4. Instanciação do Bloco 1: Sample Formatter
    sample_formatter u_formatter (
        .clk(clk),
        .rst_n(rst_n),
        .spi_data_rx(spi_data_rx),
        .spi_channel_id(spi_channel_id),
        .spi_data_valid(spi_data_valid),
        .v_sample_out(v_sample_out),
        .i_sample_out(i_sample_out),
        .sample_valid(sample_valid)
    );

    // 5. Instanciação do Bloco 2: Signal Processing
    signal_processing u_processing (
        .clk(clk),
        .rst_n(rst_n),
        .v_sample_out(v_sample_out),
        .i_sample_out(i_sample_out),
        .sample_valid(sample_valid),
        .v_signal_out(v_signal_out),
        .i_signal_out(i_signal_out),
        .signal_valid(signal_valid)
    );

    // 6. Geração do Clock (Período de 20ns = 50 MHz)
    always begin
        #10 clk = ~clk;
    end

    // Tasks auxiliares para limpar o código de estímulos
    task send_adc_data;
        input [11:0] data;
        input        channel;
        begin
            @(posedge clk);
            spi_data_rx    = data;
            spi_channel_id = channel;
            spi_data_valid = 1'b1; // Pulso de dado pronto da SPI
            @(posedge clk);
            spi_data_valid = 1'b0;
        end
    endtask

    // 7. Bloco de Estímulos
    initial begin
        // Inicialização dos sinais
        clk            = 1'b0;
        rst_n          = 1'b0;
        spi_data_rx    = 12'h000;
        spi_channel_id = 1'b0;
        spi_data_valid = 1'b0;

        // Aplica o Reset do sistema
        #40;
        rst_n = 1'b1;
        #20;

        // --- SIMULAÇÃO DO FLUXO DE DADOS ---
        // Vamos enviar valores constantes para ver a média convergir para o valor esperado.
        // Lembra que o Formatter preenche com zeros à esquerda, então 12'h400 vira 16'h0400 (1024 em decimal).
        // Média esperada após 4 amostras: 1024.

        $display("[TB] Iniciando envio de amostras de Tensão (Canal 0)...");
        send_adc_data(12'h400, 1'b0); #100; // Amostra V1
        send_adc_data(12'h400, 1'b0); #100; // Amostra V2
        send_adc_data(12'h400, 1'b0); #100; // Amostra V3
        send_adc_data(12'h400, 1'b0); #100; // Amostra V4 -> Aqui a média deve cravar em 16'h0400

        $display("[TB] Iniciando envio de amostras de Corrente (Canal 1)...");
        // Para a corrente, vamos usar 12'h200 (512 em decimal).
        send_adc_data(12'h200, 1'b1); #100; // Amostra I1
        send_adc_data(12'h200, 1'b1); #100; // Amostra I2
        send_adc_data(12'h200, 1'b1); #100; // Amostra I3
        send_adc_data(12'h200, 1'b1); #100; // Amostra I4 -> Aqui a média deve cravar em 16'h0200

        // Envia uma variação abrupta para ver o filtro suavizar
        $display("[TB] Injetando degrau de tensão para testar o filtro...");
        send_adc_data(12'h800, 1'b0); #100; // Tensão subiu para 2048 bruto

        #200;
        $display("[TB] Simulação finalizada com sucesso.");
        $finish;
    end

    // 8. Monitor de Sinais no Console (Opcional - ajuda se não quiser abrir a forma de onda)
    initial begin
        $monitor("Tempo=%0dns | SPI_Val=%b | Formatter_Val=%b | V_Filt=0x%h | I_Filt=0x%h | Filt_Ready=%b", 
                 $time, spi_data_valid, sample_valid, v_signal_out, i_signal_out, signal_valid);
    end

endmodule