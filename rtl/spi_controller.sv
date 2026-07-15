module spi_controller #(
    parameter int DATA_WIDTH = 12,
    parameter bit CPOL       = 1'b0,
    parameter bit CPHA       = 1'b0,
    parameter int CLK_DIV    = 1
)(
    input  logic                     CLK,
    input  logic                     RST_N,

    input  logic                     START,
    input  logic [DATA_WIDTH-1:0]    SDO_DATA,

    input  logic                     SDI,

    output logic [DATA_WIDTH-1:0]    SDI_DATA,

    output logic                     BUSY,
    output logic                     DONE,

    output logic                     SCLK,
    output logic                     SDO,
    output logic                     CS_N
);

localparam DIV_WIDTH = (CLK_DIV <= 1) ? 1 : $clog2(CLK_DIV);

typedef enum logic [2:0] {
    ST_IDLE,
    ST_CS_SETUP,
    ST_TRANSFER,
    ST_CS_HOLD,
    ST_IDLE_GAP
} state_t;

state_t state;

logic [DATA_WIDTH-1:0] tx_shift;
logic [DATA_WIDTH-1:0] rx_shift;

logic [$clog2(DATA_WIDTH):0] bit_cnt;

logic [DIV_WIDTH-1:0] div_cnt;

logic sclk_int;
logic sclk_toggle;

assign SCLK = BUSY ? sclk_int : CPOL;

wire leading_edge  = (CPOL == 0) ? sclk_toggle && (sclk_int==1'b1)
                                 : sclk_toggle && (sclk_int==1'b0);

wire trailing_edge = (CPOL == 0) ? sclk_toggle && (sclk_int==1'b0)
                                 : sclk_toggle && (sclk_int==1'b1);

wire sample_edge = (CPHA==0) ? leading_edge  : trailing_edge;
wire shift_edge  = (CPHA==0) ? trailing_edge : leading_edge;

always_ff @(posedge CLK or negedge RST_N)
begin

    if(!RST_N)
    begin
        state <= ST_IDLE;

        BUSY <= 0;
        DONE <= 0;

        CS_N <= 1;

        sclk_int <= CPOL;

        div_cnt <= '0;

        tx_shift <= '0;
        rx_shift <= '0;

        SDI_DATA <= '0;

        bit_cnt <= 0;

        SDO <= 0;

        sclk_toggle <= 0;
    end

    else
    begin

        DONE <= 0;
        sclk_toggle <= 0;

        //---------------------------------------
        // Clock divider
        //---------------------------------------
        if(BUSY)
        begin
            if(div_cnt == CLK_DIV-1)
            begin
                div_cnt <= 0;
                sclk_int <= ~sclk_int;
                sclk_toggle <= 1;
            end
            else
                div_cnt <= div_cnt + 1;
        end
        else
        begin
            div_cnt <= 0;
            sclk_int <= CPOL;
        end

        //---------------------------------------
        // FSM
        //---------------------------------------

        case(state)

        ST_IDLE:
        begin
            BUSY <= 0;
            CS_N <= 1;

            if(START)
            begin
                tx_shift <= SDO_DATA;
                rx_shift <= '0;
                bit_cnt  <= DATA_WIDTH;

                BUSY <= 1;

                if(CPHA==0)
                    SDO <= SDO_DATA[DATA_WIDTH-1];

                state <= ST_CS_SETUP;
            end
        end

        //---------------------------------------

        ST_CS_SETUP:
        begin
            CS_N <= 0;

            if(sclk_toggle)
            begin
                if(CPHA==1)
                    SDO <= tx_shift[DATA_WIDTH-1];

                state <= ST_TRANSFER;
            end
        end

        //---------------------------------------

        ST_TRANSFER:
        begin

            if(sample_edge)
            begin
                rx_shift <= {rx_shift[DATA_WIDTH-2:0], SDI};

                bit_cnt <= bit_cnt - 1;

                if(bit_cnt==1)
                begin
                    SDI_DATA <= {rx_shift[DATA_WIDTH-2:0], SDI};
                    state <= ST_CS_HOLD;
                end
            end

            if(shift_edge && bit_cnt>1)
            begin
                tx_shift <= {tx_shift[DATA_WIDTH-2:0],1'b0};
                SDO <= tx_shift[DATA_WIDTH-2];
            end

        end

        //---------------------------------------

        ST_CS_HOLD:
        begin
            if(sclk_toggle)
            begin
                CS_N <= 1;
                state <= ST_IDLE_GAP;
            end
        end

        //---------------------------------------

        ST_IDLE_GAP:
        begin
            if(sclk_toggle)
            begin
                BUSY <= 0;
                DONE <= 1;
                state <= ST_IDLE;
            end
        end

        endcase

    end

end

endmodule
