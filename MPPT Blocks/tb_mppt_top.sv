`timescale 1ns / 1ps

module tb_mppt_top;

    // =========================================================================
    // 1. PARÂMETROS DO TESTBENCH
    // =========================================================================
    localparam int ADC_DATA_BITS = 12;
    localparam int ADC_ID_BITS   = 4;
    localparam int SPI_DIV       = 1;
    localparam int FMT_OUT_BITS  = 16;
    localparam int N_FILTER_SAMP = 4;
    localparam int PWM_WIDTH     = 10;

    localparam int SPI_FRAME_BITS = ADC_DATA_BITS + ADC_ID_BITS;

    // IDs dos canais de teste
    localparam logic [ADC_ID_BITS-1:0] CH_V_ID = 4'h1;
    localparam logic [ADC_ID_BITS-1:0] CH_I_ID = 4'h2;

    // =========================================================================
    // 2. SINAIS E CONEXÕES INTERNAS
    // =========================================================================
    logic clk;
    logic rst_n;

    // Interface SPI
    logic spi_start;
    logic spi_sdi;
    logic spi_sclk;
    logic spi_sdo;
    logic spi_cs_n;

    // Saídas de Controle e Status
    logic pwm_out;
    logic spi_busy;
    logic mppt_cycle_done;

    // =========================================================================
    // 3. INSTANCIAÇÃO DO DUT (Design Under Test)
    // =========================================================================
    mppt_top #(
        .ADC_DATA_BITS (ADC_DATA_BITS),
        .ADC_ID_BITS   (ADC_ID_BITS),
        .SPI_DIV       (SPI_DIV),
        .FMT_OUT_BITS  (FMT_OUT_BITS),
        .N_FILTER_SAMP (N_FILTER_SAMP),
        .PWM_WIDTH     (PWM_WIDTH)
    ) dut (
        .CLK             (clk),
        .RST_N           (rst_n),
        .SPI_START       (spi_start),
        .SPI_SDI         (spi_sdi),
        .SPI_SCLK        (spi_sclk),
        .SPI_SDO         (spi_sdo),
        .SPI_CS_N        (spi_cs_n),
        .PWM_OUT         (pwm_out),
        .SPI_BUSY        (spi_busy),
        .MPPT_CYCLE_DONE (mppt_cycle_done)
    );

    // =========================================================================
    // 4. GERAÇÃO DE CLOCK (100 MHz -> Período de 10ns)
    // =========================================================================
    always #5 clk = ~clk;

    // =========================================================================
    // 5. TASK DE SIMULAÇÃO DO ADC EXTERNO (SPI SLAVE)
    // =========================================================================
    // Esta task simula a transmissão serial (MSB first) do ADC em resposta ao clock SPI.
    task automatic send_spi_frame_from_adc(
        input logic [ADC_ID_BITS-1:0]   ch_id,
        input logic [ADC_DATA_BITS-1:0] adc_data
    );
        logic [SPI_FRAME_BITS-1:0] tx_word;
        tx_word = {ch_id, adc_data};

        // Dispara o SPI Controller
        @(posedge clk);
        spi_start = 1'b1;
        @(posedge clk);
        spi_start = 1'b0;

        // Aguarda a seleção do chip (CS_N ir para baixo)
        wait(spi_cs_n == 1'b0);

        // Envia cada bit no SDI sincronizado com a amostragem do SPI (borda do SCLK)
        for (int i = SPI_FRAME_BITS - 1; i >= 0; i--) begin
            spi_sdi = tx_word[i];
            // Aguarda uma transição completa do SCLK para o próximo bit
            @(posedge spi_sclk);
            @(negedge spi_sclk);
        end

        // Aguarda o encerramento do frame SPI
        wait(spi_busy == 1'b0);
        #20;
    endtask

    // =========================================================================
    // 6. BLOCO PRINCIPAL DE ESTÍMULOS
    // =========================================================================
    initial begin
        // Arquivo VCD para visualização no GTKWave
        $dumpfile("mppt_top_sim.vcd");
        $dumpvars(0, tb_mppt_top);

        // Inicialização dos Sinais
        clk       = 1'b0;
        rst_n     = 1'b0;
        spi_start = 1'b0;
        spi_sdi   = 1'b0;

        // Reset do sistema
        #40;
        rst_n = 1'b1;
        #20;

        $display("[%0t ns] === INICIANDO SIMULAÇÃO DO MPPT TOP LEVEL ===", $time);

        // ---------------------------------------------------------------------
        // Alimentar o filtro com 4 amostras de Corrente e Tensão
        // ---------------------------------------------------------------------
        $display("[%0t ns] Enviando 4 amostras de Corrente...", $time);
        repeat(N_FILTER_SAMP) begin
          send_spi_frame_from_adc(CH_I_ID, 12'd50);
        end
        $display("[%0t ns] Enviando 4 amostras de Tensão...", $time);
        repeat(N_FILTER_SAMP) begin
          send_spi_frame_from_adc(CH_V_ID, 12'd100);
        end 
      
      	// ---------------------------------------------------------------------
        // Alimenta o filtro com amostras de Corrente e tensão para gerar variação e observar a saída PWM aumentando
        // ---------------------------------------------------------------------
      	$display("[%0t ns] Enviando amostras...", $time);
        send_spi_frame_from_adc(CH_I_ID, 12'd20);
        send_spi_frame_from_adc(CH_V_ID, 12'd200);
      	send_spi_frame_from_adc(CH_I_ID, 12'd15);
      	send_spi_frame_from_adc(CH_V_ID, 12'd250);
      	send_spi_frame_from_adc(CH_I_ID, 12'd12);
      	send_spi_frame_from_adc(CH_V_ID, 12'd255);
      	send_spi_frame_from_adc(CH_I_ID, 12'd10);
      	send_spi_frame_from_adc(CH_V_ID, 12'd260);
        // Deixa a simulação rodar para observar alguns ciclos do pulso PWM_OUT
        #40000;
      
      	// ---------------------------------------------------------------------
        // Alimentar o filtro com 4 amostras de Corrente e Tensão  para gerar variação e observar a saída PWM diminuindo
        // ---------------------------------------------------------------------
        $display("[%0t ns] Enviando 4 amostras de Corrente...", $time);
        repeat(N_FILTER_SAMP) begin
          send_spi_frame_from_adc(CH_I_ID, 12'd6);
        end
        $display("[%0t ns] Enviando 4 amostras de Tensão...", $time);
        repeat(N_FILTER_SAMP) begin
          send_spi_frame_from_adc(CH_V_ID, 12'd270);
        end 
      	// Deixa a simulação rodar para observar alguns ciclos do pulso PWM_OUT
        #16000;
      
      	// ---------------------------------------------------------------------
        // Alimentar o filtro com 4 amostras de Corrente e tensão iguais a anterior para testar se o comportamento se matém
        // ---------------------------------------------------------------------
        $display("[%0t ns] Enviando 4 amostras de Corrente...", $time);
        repeat(N_FILTER_SAMP) begin
          send_spi_frame_from_adc(CH_I_ID, 12'd6);
        end
        $display("[%0t ns] Enviando 4 amostras de Tensão...", $time);
        repeat(N_FILTER_SAMP) begin
          send_spi_frame_from_adc(CH_V_ID, 12'd270);
        end 

      // Deixa a simulação rodar para observar alguns ciclos do pulso PWM_OUT
        #20000;
      
        $display("[%0t ns] === SIMULAÇÃO FINALIZADA COM SUCESSO ===", $time);
        $finish;
    end

    // =========================================================================
    // 7. MONITORAMENTO EM TEMPO DE EXECUÇÃO
    // =========================================================================
    initial begin
      $monitor("Tempo=%0dns | DUTY_VALUE=%d", $time, dut.w_duty_value);
    end

endmodule