/*
	Duvidas:
    -
*/

module mppt_core #(parameter width = 10)(
  input wire clk,					
  input wire rst,			
  input wire valid_signal,			// Entrada que indica um sinal válido para início da lógica
  input wire [(width-1):0] V,		// Entrada com o valor de tensão atual
  input wire [(width-1):0] I,		// Entrada com o valor de corrente atual
  output wire [1:0] Dc_out,			// Saída que indica a ação a se fazer no duty_controller
  output wire valid_end_cycle		// Saída que indica para a FSM "mãe" que o ciclo foi finalizado
);
  
  
  reg [(width-1):0] V_older;		// Váriavel com o valor de tensão antigo 
  wire [(width-1):0] V_newer;		// Variável com o valor de tensão atual 
  wire [(width-1):0] delta_ref;		// Variável que contém o fator de alteração das operações (lida no banco de dados) 
  reg [(width-1):0] V_ref_older;	// Váriavel com o valor de tensão de referência antiga 
  reg [(width-1):0] V_ref_newer;	// Váriavel com o valor de tensão de referência nova
  reg [((2*width)-1):0] P_older;	// Variável com o valor da potência antiga
  wire [((2*width)-1):0] P_newer;	// Variável com o valor da potência nova 
  reg [1:0]	Dc_aux;					// Variável auxiliar para Dc_out
  reg [2:0] state;					// Variável que contém o estado atual da máquina de estados
  reg [2:0] next_state;				// Variável que contém o estado futuro da máquina de estados
  
  /* Estados da máquina de estado */
  localparam IDLE = 3'b000;			// Estado inicial, potência atual igual a anterior ou alteração por conta de corrente
  localparam P_DIFF = 3'b001;		// Potência atual diferente da anterior
  localparam PGVG_PLGL = 3'b010;	// Potência atual maior que anterior e tensão atual maior que anterior OU potência atual menor que anterior e tensão atual menor que anterior
  localparam PGVL_PLVG = 3'b011;	// Potência atual maior que anterior e tensão atual menor que anterior OU potência atual menor que anterior e tensão atual maior que anterior
  localparam V_ref_L = 3'b100;		// V_ref_newer menor que V_ref_older
  localparam V_ref_G = 3'b101;		// V_ref_newer maior que V_ref_older
  localparam END = 3'b110;			// Atualizações de variáveis
  
  wire [width:0] unused_saida;		// Variável não utilizada (preenche o espaço da leitura do banco de dados quando se deseja escrever)
  
  /* Leituras e escritas no banco de dados (desabilitado por ainda não ter sido implementado) */
  //banco_de_dados delta_ref_mem(.saida_leitura(delta_ref),.read_en(1'b1),.write_en(1'b0),.entrada_escrita({(width+1){1'b0}}),.endereco(X2),.clk(clk)); // leitura de delta_ref
  assign delta_ref = 10'd10; // Valor atribuído localmente para simular o banco de dados não implementado
  //banco_de_dados Dc_out_mem(.saida_leitura(unused_saida),.read_en(1'b0),.write_en(1'b1),.entrada_escrita(Dc_out),.endereco(X5),.clk(clk)); // Escrita de Dc_out
  
  //banco_de_dados v_older_mem(.saida_leitura(unused_saida),.read_en(1'b0),.write_en(1'b1),.entrada_escrita(V_newer),.endereco(X1),.clk(clk)); // Escrita do valor de V_older atualizado
  //banco_de_dados V_ref_older_mem(.saida_leitura(unused_saida),.read_en(1'b0),.write_en(1'b1),.entrada_escrita(V_ref_newer),.endereco(X3),.clk(clk)); // Escrita do valor de V_ref_older atualizada
  //banco_de_dados P_older_mem(.saida_leitura(unused_saida),.read_en(1'b0),.write_en(1'b1),.entrada_escrita(P_newer),.endereco(X4),.clk(clk)); // Escrita do valor de P_older atualizada
  
  assign V_newer = V;
  assign P_newer = V_newer * I;

  /* Detecta o sinal de validação */
  reg valid_d;	// Variável auxiliar para detecção da borda de subida do valid_signal
  wire valid_pulse;

  always @(posedge clk or posedge rst) begin
   	 if(rst)
        valid_d <= 1'b0;
    else
        valid_d <= valid_signal;
  end

  assign valid_pulse = valid_signal & ~valid_d;
  
  /* Atualização do estado */
  always @(posedge clk or posedge rst) begin
    if(rst) begin
      state <= IDLE;
      V_older <= 0;
      V_ref_older <= 0;
      P_older <= 0;
    end
    else begin
      state <= next_state;
      
      if (state == END) begin
       	V_older <= V_newer;
       	V_ref_older <= V_ref_newer;
       	P_older <= P_newer;
      end
    end
  end
  
  /* Lógica de transição de estados */
  always @(*) begin
    next_state = state;
    
    case(state)
      IDLE: begin
        if(valid_pulse) begin
        	if(P_newer != P_older)begin
        	  next_state = P_DIFF;
        	end
        	else begin
        	  next_state = END;
        	end
        end
        else begin
          next_state = IDLE;
        end
      end
      P_DIFF: begin
        if((P_newer > P_older && V_newer > V_older) || (P_newer < P_older && V_newer < V_older))begin
          next_state = PGVG_PLGL;
        end
        else if((P_newer > P_older && V_newer < V_older) || (P_newer < P_older && V_newer > V_older)) begin
          next_state = PGVL_PLVG;
        end
        else begin
          next_state = END;
        end
      end
      PGVG_PLGL: begin
        next_state = V_ref_G;
      end
      PGVL_PLVG: begin
        next_state = V_ref_L;
      end
      V_ref_L: begin
        next_state = END;
      end
      V_ref_G: begin
        next_state = END;
      end
      END: begin
        next_state = IDLE;
      end
      default: begin
        next_state = IDLE;
      end
    endcase
  end
  
  /* Lógica de saída */
  always @(*) begin
    V_ref_newer = V_ref_older;
    Dc_aux = 2'b10;
    
    case(state)
      IDLE: begin
      end
      P_DIFF: begin
      end
      PGVG_PLGL: begin
        V_ref_newer = V_ref_older + delta_ref;                
      end
      PGVL_PLVG: begin
        V_ref_newer = V_ref_older - delta_ref;
      end
      V_ref_L: begin
        Dc_aux = 2'b01;
      end
      V_ref_G: begin
        Dc_aux = 2'b00;
      end
      END: begin
      end
      default: begin
        Dc_aux = 2'b10;
      end
    endcase
  end

  assign Dc_out = Dc_aux;
  assign valid_end_cycle = (state == END);
  
endmodule