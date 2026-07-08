/*
      Dúvidas:
    - 
*/

module duty_controller #(parameter width = 10)(
  input wire clk,
  input wire rst,
  input wire [1:0] Dc_in,		// Entrada que indica a ação a se fazer (vem do bloco anterior)
  output wire [width:0] D_out,	// Saída que contém o valor de controle de largura de pulso do PWM
);
 
/*
      Dc_in       |     ação
    00            |     Diminui a saída em delta_d    
    01            |     Aumenta a saída em delta_d
    10            |     Mantém a saída
    11            |     --------
*/  
 
  wire [(width-1):0] delta_d;	// Variável que contém o fator de alteração das operações (vem da leitura do banco de dados)
  reg [width:0] D_older; 		// Variável que contém o último valor de D_out
  localparam [width:0] MAX_D = {(width+1){1'b1}};	// Variável para tratamento de overflow
  wire [width:0] unused_saida;	// Variável não utilizada (preenche o espaço da leitura do banco de dados quando se deseja escrever)
  
  /* Leitura do bando de dados (desabilitado por ainda não ter sido implementado) */
  //banco_de_dados delta_d_mem(.saida_leitura(delta_d),.read_en(1'b1),.write_en(1'b0),.entrada_escrita({(width+1){1'b0}}),.endereco(YYY),.clk(clk));	// leitura de delta_d
	assign delta_d  = 10'd200;	// Valor atribuído localmente para simular o banco de dados não implementado
  //  banco_de_dados D_older_mem_ren(.saida_leitura(unused_saida),.read_en(1'b0),.write_en(1'b1),.entrada_escrita(D_older),.endereco(XXX2),.clk(clk)); // Escrita de D_older
  
  assign D_out = D_older;
  
  always @(posedge clk or posedge rst) begin
    if (rst)
        D_older <= 0;
    else begin
        case (Dc_in)

            // diminuir
            2'b00: begin
              if (D_older < {{1'b0},delta_d}) begin
                    D_older <= 0;
              end
                else begin
                    D_older <= D_older - {{1'b0},delta_d};
                end
            end
            // aumentar
            2'b01: begin
              if (D_older > MAX_D - {{1'b0},delta_d}) begin
                    D_older <= MAX_D;
              end
                else begin
                    D_older <= D_older + {{1'b0},delta_d};
                end
            end
            default: begin
              D_older <= D_older;
            end
        endcase
    end
  end
  
endmodule