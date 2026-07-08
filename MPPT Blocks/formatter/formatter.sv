module sample_formatter (
    input  wire        clk,              // Clock do sistema
    input  wire        rst_n,            // Reset ativo em nível baixo

    // Interface com o SPI Master (Atualizada para os requisitos de image_b00b02.png)
    input  wire [15:0] spi_frame_rx,     // Frame completo de 16-bit contendo [Channel_ID + Sample]
    input  wire        spi_data_valid,   // Pulso indicador de dado pronto da SPI

    // Interface com o Signal Processing
    output reg  [15:0] v_sample_out,     // Amostra formatada de Tensão (16-bit)
    output reg  [15:0] i_sample_out,     // Amostra formatada de Corrente (16-bit)
    output reg         sample_valid      // Pulso de 1 ciclo indicando nova amostra pronta
);

    // Definição dos Estados da FSM
    localparam STATE_IDLE          = 2'b00,
               STATE_EXTEND_ALIGN = 2'b01,
               STATE_CH_SEPARATOR = 2'b10,
               STATE_REG_OUTPUT   = 2'b11;

    reg [1:0] current_state, next_state;

    // Registradores internos adaptados
    reg [15:0] r_formatted_data;
    reg [3:0]  r_channel_id;     // Registrador de 4 bits para armazenar o ID do Canal [15:12]
    reg [11:0] r_adc_sample;     // Registrador de 12 bits para armazenar o dado bruto [11:0]

    // 1. Transição de Estados (Lógica Sequencial)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= STATE_IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // 2. Lógica do Próximo Estado (Combinacional)
    always @(*) begin
        case (current_state)
            STATE_IDLE: begin
                if (spi_data_valid)
                    next_state = STATE_EXTEND_ALIGN;
                else
                    next_state = STATE_IDLE;
            end
            
            STATE_EXTEND_ALIGN: begin
                next_state = STATE_CH_SEPARATOR;
            end
            
            STATE_CH_SEPARATOR: begin
                next_state = STATE_REG_OUTPUT;
            end
            
            STATE_REG_OUTPUT: begin
                next_state = STATE_IDLE;
            end
            
            default: next_state = STATE_IDLE;
        endcase
    end

    // 3. Lógica de Sinais Internos e Saídas (Sequencial)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v_sample_out     <= 16'h0000;
            i_sample_out     <= 16'h0000;
            sample_valid     <= 1'b0;
            r_formatted_data <= 16'h0000;
            r_channel_id     <= 4'h0;
            r_adc_sample     <= 12'h000;
        end else begin
            // Default: pulso de valid dura apenas 1 ciclo de clock
            sample_valid <= 1'b0;

            case (current_state)
                STATE_IDLE: begin
                    if (spi_data_valid) begin
                        // Separa e armazena os campos do frame SPI conforme image_b00b02.png
                        r_channel_id <= spi_frame_rx[15:12];
                        r_adc_sample <= spi_frame_rx[11:0];
                    end
                end

                STATE_EXTEND_ALIGN: begin
                    // Alinhamento: Preenche com zeros à esquerda [15:12] transformando 12 bits em 16 bits
                    r_formatted_data <= {4'b0000, r_adc_sample};
                end

                STATE_CH_SEPARATOR: begin
                    // Encaminha usando os IDs da especificação (image_b00b02.png e image_b073c7.png)
                    if (r_channel_id == 4'h1) begin       // 0x1 = PV Voltage
                        v_sample_out <= r_formatted_data;
                    end else if (r_channel_id == 4'h2) begin // 0x2 = PV Current
                        i_sample_out <= r_formatted_data;
                    end
                end

                STATE_REG_OUTPUT: begin
                    // Ativa a flag de saída para o próximo bloco disparar
                    sample_valid <= 1'b1;
                end
            endcase
        end
    end

endmodule
