`timescale 1ns / 1ps

module tb_mppt_signal_chain;

    // 1. Sinais Globais
    reg clk;
    reg rst_n;

    // 2. Conexões Intermediárias Modificadas (Acordo com image_b00b02.png)
    reg  [15:0] spi_frame_rx;      // Envia o barramento integrado completo de 16 bits
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
        .spi_frame_rx(spi_frame_rx),
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

    // Task auxiliar ajustada para concatenar ID e Dados conforme image_b00b02.png
    task send_adc_data;
        input [11:0] data;
        input [3:0]  channel_id;   // Agora recebe o identificador de 4 bits
        begin
            @(posedge clk);
            spi_frame_rx   = {channel_id, data}; // Montagem exata da estrutura do frame
            spi_data_valid = 1'b1; 
            @(posedge clk);
            spi_data_valid = 1'b0;
        end
    endtask

    // 7. Bloco de Estímulos com os dados reais de image_b073c7.png
    initial begin
        // Inicialização dos sinais
        clk            = 1'b0;
        rst_n          = 1'b0;
        spi_frame_rx   = 16'h0000;
        spi_data_valid = 1'b0;

        // Aplica o Reset do sistema
        #40;
        rst_n = 1'b1;
        #20;

        // --- SIMULAÇÃO COM OS CASOS DA IMAGEM image_b073c7.png ---

        // 1. Caso de Tensão: PV Voltage = 38V -> ADC = 2358 (0x936) | ID = 0x1
        // Frame resultante enviado: 16'h1936
        $display("[TB] Iniciando envio de amostras de Tensão (38V -> 12'h936, Canal 0x1)...");
        send_adc_data(12'h936, 4'h1); #100; // Amostra V1
        send_adc_data(12'h936, 4'h1); #100; // Amostra V2
        send_adc_data(12'h936, 4'h1); #100; // Amostra V3
        send_adc_data(12'h936, 4'h1); #100; // Amostra V4 -> Aqui V_Filt deve cravar em 16'h0936

        // 2. Caso de Corrente: PV Current = 8A -> ADC = 2978 (0xBA2) | ID = 0x2
        // Frame resultante enviado: 16'h2BA2
        $display("[TB] Iniciando envio de amostras de Corrente (8A -> 12'hBA2, Canal 0x2)...");
        send_adc_data(12'hBA2, 4'h2); #100; // Amostra I1
        send_adc_data(12'hBA2, 4'h2); #100; // Amostra I2
        send_adc_data(12'hBA2, 4'h2); #100; // Amostra I3
        send_adc_data(12'hBA2, 4'h2); #100; // Amostra I4 -> Aqui I_Filt deve cravar em 16'h0BA2

        // Opcional: Mantido o teste de degrau usando a nova configuração de ID de Tensão (0x1)
        $display("[TB] Injetando degrau de tensão para testar o filtro...");
        send_adc_data(12'hC00, 4'h1); #100; // Modifica o degrau para 12'hC00 com ID de tensão

        #200;
        $display("[TB] Simulação finalizada com sucesso.");
        $finish;
    end

    // 8. Monitor de Sinais atualizado para imprimir os estados corretos
    initial begin
        $monitor("Tempo=%0dns | SPI_Frame=0x%h | Formatter_Val=%b | V_Filt=0x%h | I_Filt=0x%h | Filt_Ready=%b", 
                 $time, spi_frame_rx, sample_valid, v_signal_out, i_signal_out, signal_valid);
    end

endmodule