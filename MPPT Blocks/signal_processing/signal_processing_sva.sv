/* Assertions para a verificação dos testes:
	3.1
    3.11
    3.12 preciso mesmo?
*/

module signal_processing_sva(

    input logic clk,
    input logic rst_n,
    input logic sample_valid,
    input logic signal_valid,
  	input logic [15:0] v_signal_out,
    input logic [15:0] i_signal_out
);

  // Sinais de saída devem zerar (3.1)
  	property outputs_reset;
    @(posedge clk)
    !rst_n |-> (
        v_signal_out == 16'd0 &&
        i_signal_out == 16'd0 &&
        signal_valid == 1'b0
    );
	endproperty

  	assert property(outputs_reset);
  
    //3.11
    // signal_valid deve ser pulso de 1 ciclo
    property signal_valid_single_cycle;
        @(posedge clk) disable iff(!rst_n)
        signal_valid |-> ##1 !signal_valid;
    endproperty

    assert property(signal_valid_single_cycle);

   // signal_valid não pode ocorrer durante reset
    property no_signal_valid_during_reset;
        @(posedge clk)
        !rst_n |-> !signal_valid;
    endproperty

    assert property(no_signal_valid_during_reset);

    // signal_valid deve ocorrer após uma amostra válida
    property signal_valid_after_sample;
        @(posedge clk) disable iff(!rst_n)
      $rose(sample_valid) |-> ##[1:5] signal_valid; // acredito que ##4 sirva
    endproperty

    assert property(signal_valid_after_sample);

endmodule