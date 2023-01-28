module walking_bit_gen #(
    parameter WIDTH = 5
    ) (i_clk, i_enable, o_data);

    input wire i_clk, i_enable;
    output wire [(2**WIDTH)-1:0] o_data;

	wire [(2**WIDTH)-1:0] data;
	
    reg [WIDTH-1:0] counter = 0;
    always @(posedge i_clk) begin
        if (i_enable) begin
            counter <= counter + 1;
        end
    end
    onehot_enc 
    #(
        .WIDTH (WIDTH )
    )
    u_onehot_enc(
        .in  (counter),
        .out (data )
    );
	
	/*always @(posedge i_clk) begin
		o_data <= data;
	end*/
    assign o_data = data;
    
endmodule


module onehot_enc #(
    parameter WIDTH = 5
    ) (
    input wire [WIDTH-1:0] in,
    output wire [(2**WIDTH)-1:0] out
    );
	
	assign out = 1 << in;
endmodule