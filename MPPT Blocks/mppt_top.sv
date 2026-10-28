`timescale 1ns / 1ps

module mppt_top #(
    // Parâmetros do ADC e Comunicação SPI
    parameter int ADC_DATA_BITS = 12,   // Bits de resolução do dado bruto do ADC
    parameter int ADC_ID_BITS   = 4,    // Bits do ID do Canal no frame SPI
    parameter int SPI_DIV       = 1,    // Divisor de clock do SPI Controller
    
    // Parâmetros do Processamento de Sinal
    parameter int FMT_OUT_BITS  = 16,   // Largura da palavra formatada de saída
    parameter int N_FILTER_SAMP = 4,    // Número de amostras para o filtro de média móvel (2, 4, 8, 16...)

    // Parâmetros do Algoritmo MPPT e PWM
    parameter int PWM_WIDTH     = 10    // Resolução do PWM (10 bits)
)(
    input  wire CLK,               // Clock do sistema
    input  wire RST_N,             // Reset ativo em nível baixo

    // Interface SPI Externa (Conexão com ADC)
    input  wire SPI_START,         // Sinal para disparar leitura do ADC
    input  wire SPI_SDI,           // Serial Data In do ADC
    output wire SPI_SCLK,          // Clock do SPI
    output wire SPI_SDO,           // Serial Data Out para o ADC
    output wire SPI_CS_N,          // Chip Select (Ativo em baixo)

    // Saída de Controle de Potência
    output wire PWM_OUT,           // Sinal PWM gerado para o conversor DC-DC

    // Status / Flags para monitoramento externo
    output wire SPI_BUSY,          // SPI em transferência
    output wire MPPT_CYCLE_DONE    // Indicação de fim do ciclo do algoritmo MPPT
);

    // Cálculo local do tamanho total do frame SPI (ID + Dado)
    localparam int SPI_FRAME_BITS = ADC_DATA_BITS + ADC_ID_BITS;

    // Inversão do reset para os módulos com reset ativo em nível alto
    wire rst_high = ~RST_N;

    // =========================================================================
    // SINAIS INTERNOS DE CONEXÃO
    // =========================================================================

    // 1. SPI Controller -> Sample Formatter
    wire [SPI_FRAME_BITS-1:0] w_spi_sdi_data;
    wire                     w_spi_done;

    // 2. Sample Formatter -> Signal Processing
    wire [FMT_OUT_BITS-1:0]  w_v_sample;
    wire [FMT_OUT_BITS-1:0]  w_i_sample;
    wire                     w_sample_valid;

    // 3. Signal Processing -> MPPT Core
    wire [FMT_OUT_BITS-1:0]  w_v_filtered;
    wire [FMT_OUT_BITS-1:0]  w_i_filtered;
    wire                     w_signal_valid;

    // 4. MPPT Core -> Duty Controller
    wire [1:0]               w_dc_action;

    // 5. Duty Controller -> PWM Generator
    wire [PWM_WIDTH:0]       w_duty_value;

    // =========================================================================
    // INSTANCIAÇÃO DOS BLOCOS
    // =========================================================================

    // 1. Controlador SPI Master (Parametrizável)
    spi_controller #(
        .DATA_WIDTH (SPI_FRAME_BITS),
        .CPOL       (1'b0),
        .CPHA       (1 'b0),
        .CLK_DIV    (SPI_DIV)
    ) u_spi_controller (
        .CLK        (CLK),
        .RST_N      (RST_N),
        .START      (SPI_START),
        .SDO_DATA   ({SPI_FRAME_BITS{1'b0}}),
        .SDI        (SPI_SDI),
        .SDI_DATA   (w_spi_sdi_data),
        .BUSY       (SPI_BUSY),
        .DONE       (w_spi_done),
        .SCLK       (SPI_SCLK),
        .SDO        (SPI_SDO),
        .CS_N       (SPI_CS_N)
    );

    // 2. Sample Formatter (Parametrizável)
    sample_formatter #(
        .ADC_WIDTH   (ADC_DATA_BITS),
        .CH_ID_WIDTH (ADC_ID_BITS),
        .OUT_WIDTH   (FMT_OUT_BITS),
        .CH_V_ID     (4'h1),  // ID do canal de tensão
        .CH_I_ID     (4'h2)   // ID do canal de corrente
    ) u_sample_formatter (
        .clk            (CLK),
        .rst_n          (RST_N),
        .spi_frame_rx   (w_spi_sdi_data),
        .spi_data_valid (w_spi_done),
        .v_sample_out   (w_v_sample),
        .i_sample_out   (w_i_sample),
        .sample_valid   (w_sample_valid)
    );

    // 3. Signal Processing / Média Móvel (Parametrizável)
    signal_processing #(
        .DATA_WIDTH (FMT_OUT_BITS),
        .N_SAMPLES  (N_FILTER_SAMP)
    ) u_signal_processing (
        .clk          (CLK),
        .rst_n        (RST_N),
        .v_sample_out (w_v_sample),
        .i_sample_out (w_i_sample),
        .sample_valid (w_sample_valid),
        .v_signal_out (w_v_filtered),
        .i_signal_out (w_i_filtered),
        .signal_valid (w_signal_valid)
    );

    // 4. MPPT Core - Algoritmo Perturb & Observe
    // Converte/Trunca o dado de 16-bit para a resolução interna do algoritmo (10 bits)
    mppt_core #(
        .width (PWM_WIDTH)
    ) u_mppt_core (
        .clk             (CLK),
        .rst             (rst_high),
        .valid_signal    (w_signal_valid),
        .V               (w_v_filtered[PWM_WIDTH-1:0]),
        .I               (w_i_filtered[PWM_WIDTH-1:0]),
        .Dc_out          (w_dc_action),
        .valid_end_cycle (MPPT_CYCLE_DONE)
    );

    // 5. Duty Controller - Atualiza o registrador de razão cíclica
    duty_controller #(
        .width (PWM_WIDTH)
    ) u_duty_controller (
        .clk            (CLK),
        .rst            (rst_high),
        .valid_input    (MPPT_CYCLE_DONE),
        .Dc_in          (w_dc_action),
        .D_out          (w_duty_value)
    );

    // 6. PWM Generator - Gera o pulso PWM de saída
    pwm_generator #(
        .width (PWM_WIDTH)
    ) u_pwm_generator (
        .clk     (CLK),
        .rst     (rst_high),
        .D_in    (w_duty_value),
        .pwm_out (PWM_OUT)
    );

endmodule