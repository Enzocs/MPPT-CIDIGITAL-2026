module pwm_generator #(parameter width = 10)(
    input  wire             clk,
    input  wire             rst,
 	input  wire [width:0]   D_in,	// Entrada que controla a largura de pulso
    output wire             pwm_out	// Saída da onda PWM
);

    reg [width:0] counter;

    localparam [width:0] MAX_D = {(width+1){1'b1}};

    always @(posedge clk or posedge rst) begin
        if (rst)
            counter <= {(width+1){1'b0}};
        else
            counter <= counter + 1'b1;
    end

    assign pwm_out = (D_in == MAX_D) ? 1'b1 :
                     (counter < D_in);

endmodule