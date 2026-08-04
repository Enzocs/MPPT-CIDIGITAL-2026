module sample_formatter #(
    parameter int ADC_WIDTH   = 12,                  // Bits de dados do ADC
    parameter int CH_ID_WIDTH = 4,                   // Bits do ID do Canal
    parameter int OUT_WIDTH   = 16,                  // Largura da saída formatada
    parameter logic [CH_ID_WIDTH-1:0] CH_V_ID = 4'h1, // ID do Canal de Tensão
    parameter logic [CH_ID_WIDTH-1:0] CH_I_ID = 4'h2  // ID do Canal de Corrente
)(
    input  wire                   clk,
    input  wire                   rst_n,

    // Interface SPI
    input  wire [CH_ID_WIDTH+ADC_WIDTH-1:0] spi_frame_rx, // Frame [Channel_ID + Sample]
    input  wire                             spi_data_valid,

    // Saídas Formatadas
    output reg  [OUT_WIDTH-1:0]   v_sample_out,
    output reg  [OUT_WIDTH-1:0]   i_sample_out,
    output reg                    sample_valid
);

    localparam int TOTAL_FRAME_WIDTH = CH_ID_WIDTH + ADC_WIDTH;
    localparam int PADDING_BITS      = OUT_WIDTH - ADC_WIDTH;

    // Estados da FSM
    typedef enum logic [1:0] {
        STATE_IDLE,
        STATE_EXTEND_ALIGN,
        STATE_CH_SEPARATOR,
        STATE_REG_OUTPUT
    } state_t;

    state_t current_state, next_state;

    // Registradores internos
    reg [OUT_WIDTH-1:0]       r_formatted_data;
    reg [CH_ID_WIDTH-1:0]     r_channel_id;
    reg [ADC_WIDTH-1:0]       r_adc_sample;

    // 1. Transição de Estados
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            current_state <= STATE_IDLE;
        else
            current_state <= next_state;
    end

    // 2. Lógica de Próximo Estado
    always_comb begin
        case (current_state)
            STATE_IDLE:          next_state = spi_data_valid ? STATE_EXTEND_ALIGN : STATE_IDLE;
            STATE_EXTEND_ALIGN:  next_state = STATE_CH_SEPARATOR;
            STATE_CH_SEPARATOR:  next_state = STATE_REG_OUTPUT;
            STATE_REG_OUTPUT:    next_state = STATE_IDLE;
            default:             next_state = STATE_IDLE;
        endcase
    end

    // 3. Processamento de Sinais
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v_sample_out     <= '0;
            i_sample_out     <= '0;
            sample_valid     <= 1'b0;
            r_formatted_data <= '0;
            r_channel_id     <= '0;
            r_adc_sample     <= '0;
        end else begin
            sample_valid <= 1'b0;

            case (current_state)
                STATE_IDLE: begin
                    if (spi_data_valid) begin
                        r_channel_id <= spi_frame_rx[TOTAL_FRAME_WIDTH-1 -: CH_ID_WIDTH];
                        r_adc_sample <= spi_frame_rx[ADC_WIDTH-1:0];
                    end
                end

                STATE_EXTEND_ALIGN: begin
                    // Zero-padding dinâmico à esquerda
                    if (OUT_WIDTH >= ADC_WIDTH) begin
                        r_formatted_data <= {{(PADDING_BITS){1'b0}}, r_adc_sample};
                    end else begin
                        // Caso OUT_WIDTH seja menor que o ADC, trunca
                        r_formatted_data <= r_adc_sample[ADC_WIDTH-1 -: OUT_WIDTH];
                    end
                end

                STATE_CH_SEPARATOR: begin
                    if (r_channel_id == CH_V_ID) begin
                        v_sample_out <= r_formatted_data;
                    end else if (r_channel_id == CH_I_ID) begin
                        i_sample_out <= r_formatted_data;
                    end
                end

                STATE_REG_OUTPUT: begin
                    sample_valid <= 1'b1;
                end
            endcase
        end
    end

endmodule