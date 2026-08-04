module signal_processing #(
    parameter int DATA_WIDTH = 16, // Largura de bits dos dados de entrada/saída
    parameter int N_SAMPLES  = 4   // Número de amostras para o filtro de média móvel (deve ser potência de 2: 2, 4, 8, 16...)
)(
    input  wire                  clk,
    input  wire                  rst_n,

    // Interface com o Formatter
    input  wire [DATA_WIDTH-1:0] v_sample_out,
    input  wire [DATA_WIDTH-1:0] i_sample_out,
    input  wire                  sample_valid,

    // Saídas Filtradas
    output reg  [DATA_WIDTH-1:0] v_signal_out,
    output reg  [DATA_WIDTH-1:0] i_signal_out,
    output reg                   signal_valid
);

    // Cálculo dinâmico de bits para o somador e shift
    localparam int SHIFT_BITS = $clog2(N_SAMPLES);
    localparam int SUM_WIDTH  = DATA_WIDTH + SHIFT_BITS;

    // Estados da FSM
    typedef enum logic [1:0] {
        STATE_IDLE,
        STATE_REG_PIPELINE,
        STATE_SUM_N_SHIFT,
        STATE_FILTER_VALID
    } state_t;

    state_t current_state, next_state;

    // Registradores de histórico (Pipeline/Buffer circular)
    reg [DATA_WIDTH-1:0] v_reg [0:N_SAMPLES-1];
    reg [DATA_WIDTH-1:0] i_reg [0:N_SAMPLES-1];

    // Registradores do Somador com largura ajustável
    reg [SUM_WIDTH-1:0] v_sum;
    reg [SUM_WIDTH-1:0] i_sum;

    integer k;

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
            STATE_IDLE:          next_state = sample_valid ? STATE_REG_PIPELINE : STATE_IDLE;
            STATE_REG_PIPELINE:  next_state = STATE_SUM_N_SHIFT;
            STATE_SUM_N_SHIFT:   next_state = STATE_FILTER_VALID;
            STATE_FILTER_VALID:  next_state = STATE_IDLE;
            default:             next_state = STATE_IDLE;
        endcase
    end

    // 3. Lógica do Filtro e Cálculo da Média
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v_signal_out <= '0;
            i_signal_out <= '0;
            signal_valid <= 1'b0;
            v_sum        <= '0;
            i_sum        <= '0;

            for (k = 0; k < N_SAMPLES; k = k + 1) begin
                v_reg[k] <= '0;
                i_reg[k] <= '0;
            end
        end else begin
            signal_valid <= 1'b0;

            case (current_state)
                STATE_IDLE: begin
                    // Aguarda o disparo
                end

                STATE_REG_PIPELINE: begin
                    // Deslocamento genérico do histórico para N posições
                    for (k = N_SAMPLES-1; k > 0; k = k - 1) begin
                        v_reg[k] <= v_reg[k-1];
                        i_reg[k] <= i_reg[k-1];
                    end
                    v_reg[0] <= v_sample_out;
                    i_reg[0] <= i_sample_out;
                end

                STATE_SUM_N_SHIFT: begin
                    // Acumulador genérico para N amostras
                    automatic logic [SUM_WIDTH-1:0] v_acc = '0;
                    automatic logic [SUM_WIDTH-1:0] i_acc = '0;

                    for (k = 0; k < N_SAMPLES; k = k + 1) begin
                        v_acc = v_acc + v_reg[k];
                        i_acc = i_acc + i_reg[k];
                    end

                    v_sum <= v_acc;
                    i_sum <= i_acc;
                end

                STATE_FILTER_VALID: begin
                    // Divisão parametrizada via Shift Right ($clog2(N_SAMPLES))
                    v_signal_out <= v_sum[SUM_WIDTH-1 : SHIFT_BITS];
                    i_signal_out <= i_sum[SUM_WIDTH-1 : SHIFT_BITS];
                    signal_valid <= 1'b1;
                end
            endcase
        end
    end

endmodule