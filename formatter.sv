    input  wire        rst_n,            // Reset ativo em nível baixo

    // Interface com o SPI Master
    input  wire [11:0] spi_data_rx,      // Dado bruto de 12 bits vindo do ADC
    input  wire        spi_channel_id,   // 0 para Tensão (V), 1 para Corrente (I)
    input  wire        spi_data_valid,   // Pulso indicador de dado pronto da SPI

    // Interface com o Signal Processing
    output reg  [15:0] v_sample_out,     // Amostra formatada de Tensão (16-bit)
    output reg  [15:0] i_sample_out,     // Amostra formatada de Corrente (16-bit)
    output reg         sample_valid      // Pulso de 1 ciclo indicando nova amostra pronta
);

    // Definição dos Estados da FSM
    localparam STATE_IDLE         = 2'b00,
               STATE_EXTEND_ALIGN = 2'b01,
               STATE_CH_SEPARATOR = 2'b10,
               STATE_REG_OUTPUT   = 2'b11;

    reg [1:0] current_state, next_state;

    // Registradores internos para reter o dado durante o processamento
    reg [15:0] r_formatted_data;
    reg        r_channel_select;

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
            r_channel_select <= 1'b0;
        end else begin
            // Default: pulso de valid dura apenas 1 ciclo de clock
            sample_valid <= 1'b0;

            case (current_state)
                STATE_IDLE: begin
                    if (spi_data_valid) begin
                        // Salva qual canal disparou a leitura para usar nos estados seguintes
                        r_channel_select <= spi_channel_id;
                    end
                end

                STATE_EXTEND_ALIGN: begin
                    // Alinhamento: Adiciona zeros à esquerda para transformar 12 bits em 16 bits.
                    // Se o seu dado for sinalizado (complemento de dois), mude para: 
                    // r_formatted_data <= {{4{spi_data_rx[11]}}, spi_data_rx};
                    r_formatted_data <= {4'b0000, spi_data_rx};
                end

                STATE_CH_SEPARATOR: begin
                    // Encaminha o dado formatado para o registrador do canal correto
                    if (r_channel_select == 1'b0) begin
                        v_sample_out <= r_formatted_data;
                    end else begin
                        i_sample_out <= r_formatted_data;
                    end
                end

                STATE_REG_OUTPUT: begin
                    // Ativa a flag de saída indicando que o Signal Processing já pode ler
                    sample_valid <= 1'b1;
                end
            endcase
        end
    end

endmodule