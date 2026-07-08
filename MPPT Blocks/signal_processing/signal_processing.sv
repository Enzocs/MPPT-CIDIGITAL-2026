module signal_processing (
    input  wire        clk,              // Clock do sistema
    input  wire        rst_n,            // Reset ativo em nível baixo

    // Interface com o Sample Formatter
    input  wire [15:0] v_sample_out,     // Amostra de Tensão vinda do Formatter
    input  wire [15:0] i_sample_out,     // Amostra de Corrente vinda do Formatter
    input  wire        sample_valid,     // Pulso indicador de nova amostra pronta

    // Interface com o MPPT Core / Register Bank
    output reg  [15:0] v_signal_out,     // Tensão filtrada (Média Móvel)
    output reg  [15:0] i_signal_out,     // Corrente filtrada (Média Móvel)
    output reg         signal_valid      // Pulso indicando que a média foi atualizada
);

    // Definição dos Estados da FSM
    localparam STATE_IDLE          = 2'b00,
               STATE_REG_PIPELINE = 2'b01,
               STATE_SUM_N_SHIFT  = 2'b10,
               STATE_FILTER_VALID = 2'b11;

    reg [1:0] current_state, next_state;

    // Histórico de amostras (Fila/Pipeline de 4 posições para cada canal)
    reg [15:0] v_reg [0:3];
    reg [15:0] i_reg [0:3];

    // Registradores para armazenar o resultado da soma (18 bits para evitar overflow)
    reg [17:0] v_sum;
    reg [17:0] i_sum;

    integer k;

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
                if (sample_valid)
                    next_state = STATE_REG_PIPELINE;
                else
                    next_state = STATE_IDLE;
            end
            
            STATE_REG_PIPELINE: begin
                next_state = STATE_SUM_N_SHIFT;
            end
            
            STATE_SUM_N_SHIFT: begin
                next_state = STATE_FILTER_VALID;
            end
            
            STATE_FILTER_VALID: begin
                next_state = STATE_IDLE;
            end
            
            default: next_state = STATE_IDLE;
        endcase
    end

    // 3. Lógica de Pipeline, Filtro e Saídas (Sequencial)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v_signal_out <= 16'h0000;
            i_signal_out <= 16'h0000;
            signal_valid <= 1'b0;
            v_sum        <= 18'h00000;
            i_sum        <= 18'h00000;
            
            // Inicializa o histórico do filtro com zeros
            for (k = 0; k < 4; k = k + 1) begin
                v_reg[k] <= 16'h0000;
                i_reg[k] <= 16'h0000;
            end
        end else begin
            // Default: flag de pronto dura apenas 1 ciclo
            signal_valid <= 1'b0;

            case (current_state)
                STATE_IDLE: begin
                    // Aguarda o disparo do bloco anterior
                end

                STATE_REG_PIPELINE: begin
                    // Desloca o histórico e insere a nova amostra no início (Posição 0)
                    v_reg[3] <= v_reg[2];
                    v_reg[2] <= v_reg[1];
                    v_reg[1] <= v_reg[0];
                    v_reg[0] <= v_sample_out;

                    i_reg[3] <= i_reg[2];
                    i_reg[2] <= i_reg[1];
                    i_reg[1] <= i_reg[0];
                    i_reg[0] <= i_sample_out;
                end

                STATE_SUM_N_SHIFT: begin
                    // Soma as 4 posições do histórico
                    v_sum <= v_reg[0] + v_reg[1] + v_reg[2] + v_reg[3];
                    i_sum <= i_reg[0] + i_reg[1] + i_reg[2] + i_reg[3];
                end

                STATE_FILTER_VALID: begin
                    // Divide por 4 usando Shift Right de 2 bits
                    v_signal_out <= v_sum[17:2];
                    i_signal_out <= i_sum[17:2];
                    
                    // Dispara o sinal de pronto para o MPPT Core
                    signal_valid <= 1'b1;
                end
            endcase
        end
    end

endmodule