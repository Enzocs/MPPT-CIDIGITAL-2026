`timescale 1ns / 1ps

module tb_mppt_signal_chain;

    // =========================================================================
    // 1. PARÂMETROS DA CADEIA DE SINAL
    // =========================================================================
    localparam int ADC_WIDTH   = 12;   // Resolução dos dados do ADC (12 bits)
    localparam int CH_ID_WIDTH = 4;    // Bits para identificação do canal (4 bits)
    localparam int OUT_WIDTH   = 16;   // Largura da palavra formatada (16 bits)
    localparam int N_SAMPLES   = 4;    // Quantidade de amostras no filtro de média móvel

    localparam logic [CH_ID_WIDTH-1:0] CH_V_ID = 4'h1; // ID do canal de Tensão
    localparam logic [CH_ID_WIDTH-1:0] CH_I_ID = 4'h2; // ID do canal de Corrente

    localparam int FRAME_WIDTH = ADC_WIDTH + CH_ID_WIDTH; // 16 bits no total

    // =========================================================================
    // 2. SINAIS E CONEXÕES INTERNAS (logic)
    // =========================================================================
    logic clk;
    logic rst_n;

    // Conexões com o Formatter
    logic [FRAME_WIDTH-1:0] spi_frame_rx;
    logic                   spi_data_valid;

    // Conexões entre Formatter e Signal Processing
    logic [OUT_WIDTH-1:0]   v_sample_out;
    logic [OUT_WIDTH-1:0]   i_sample_out;
    logic                   sample_valid;

    // Saídas Finais do Signal Processing
    logic [OUT_WIDTH-1:0]   v_signal_out;
    logic [OUT_WIDTH-1:0]   i_signal_out;
    logic                   signal_valid;

    // =========================================================================
    // 3. INSTANCIAÇÃO DOS BLOCOS PARAMETRIZADOS
    // =========================================================================

    // Bloco 1: Sample Formatter
    sample_formatter #(
        .ADC_WIDTH   (ADC_WIDTH),
        .CH_ID_WIDTH (CH_ID_WIDTH),
        .OUT_WIDTH   (OUT_WIDTH),
        .CH_V_ID     (CH_V_ID),
        .CH_I_ID     (CH_I_ID)
    ) u_formatter (
        .clk            (clk),
        .rst_n          (rst_n),
        .spi_frame_rx   (spi_frame_rx),
        .spi_data_valid (spi_data_valid),
        .v_sample_out   (v_sample_out),
        .i_sample_out   (i_sample_out),
        .sample_valid   (sample_valid)
    );

    // Bloco 2: Signal Processing (Filtro Média Móvel)
    signal_processing #(
        .DATA_WIDTH (OUT_WIDTH),
        .N_SAMPLES  (N_SAMPLES)
    ) u_processing (
        .clk          (clk),
        .rst_n        (rst_n),
        .v_sample_out (v_sample_out),
        .i_sample_out (i_sample_out),
        .sample_valid (sample_valid),
        .v_signal_out (v_signal_out),
        .i_signal_out (i_signal_out),
        .signal_valid (signal_valid)
    );

    // =========================================================================
    // 4. GERAÇÃO DE CLOCK (50 MHz -> Período de 20ns)
    // =========================================================================
    always begin
        #10 clk = ~clk;
    end

    // =========================================================================
    // 5. TASKS AUXILIARES
    // =========================================================================
    // Concatena o ID do canal com o dado bruto do ADC dinamicamente
    task automatic send_adc_data(
        input logic [ADC_WIDTH-1:0]   data,
        input logic [CH_ID_WIDTH-1:0] channel_id
    );
        begin
            @(posedge clk);
            spi_frame_rx   = {channel_id, data};
            spi_data_valid = 1'b1;
            @(posedge clk);
            spi_data_valid = 1'b0;
        end
    endtask

    // =========================================================================
    // 6. BLOCO DE ESTÍMULOS E SIMULAÇÃO
    // =========================================================================
    initial begin
        // Arquivo de onda para visualização no GTKWave
        $dumpfile("signal_chain_sim.vcd");
        $dumpvars(0, tb_mppt_signal_chain);

        // Inicialização dos Sinais
        clk            = 1'b0;
        rst_n          = 1'b0;
        spi_frame_rx   = '0;
        spi_data_valid = 1'b0;

        // Aplicação de Reset
        #40;
        rst_n = 1'b1;
        #20;

        // --- 1. TESTE DE TENSAO (PV Voltage = 38V -> ADC = 0x936 | ID = 0x1) ---
        $display("[%0t ns] [TB] Enviando 4 amostras de Tensao (38V -> 12'h936, Canal 0x1)...", $time);
        send_adc_data(12'h936, CH_V_ID); #100; // Amostra 1
        send_adc_data(12'h936, CH_V_ID); #100; // Amostra 2
        send_adc_data(12'h936, CH_V_ID); #100; // Amostra 3
        send_adc_data(12'h936, CH_V_ID); #100; // Amostra 4 -> V_Filt deve cravar em 16'h0936

        // --- 2. TESTE DE CORRENTE (PV Current = 8A -> ADC = 0xBA2 | ID = 0x2) ---
        $display("[%0t ns] [TB] Enviando 4 amostras de Corrente (8A -> 12'hBA2, Canal 0x2)...", $time);
        send_adc_data(12'hBA2, CH_I_ID); #100; // Amostra 1
        send_adc_data(12'hBA2, CH_I_ID); #100; // Amostra 2
        send_adc_data(12'hBA2, CH_I_ID); #100; // Amostra 3
        send_adc_data(12'hBA2, CH_I_ID); #100; // Amostra 4 -> I_Filt deve cravar em 16'h0BA2

        // --- 3. TESTE DE DEGRAU DE TENSÃO ---
        $display("[%0t ns] [TB] Injetando degrau de tensao (12'hC00) para observar a resposta do filtro...", $time);
        send_adc_data(12'hC00, CH_V_ID); #100;

        #200;
        $display("[%0t ns] [TB] Simulacao finalizada com sucesso.", $time);
        $finish;
    end

    // =========================================================================
    // 7. MONITOR DE SINAIS
    // =========================================================================
    initial begin
        $monitor("Tempo=%0dns | SPI_Frame=0x%h | Formatter_Val=%b | V_Filt=0x%h | I_Filt=0x%h | Filt_Ready=%b", 
                 $time, spi_frame_rx, sample_valid, v_signal_out, i_signal_out, signal_valid);
    end

endmodule