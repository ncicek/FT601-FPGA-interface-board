module sync (i_clk_in, i_data, i_clk_out, o_data);
    input wire i_clk_in, i_data, i_clk_out;
    output reg o_data;

    reg data_glitchfree, data_meta;
    always @(posedge i_clk_in) 
            data_glitchfree <= i_data; 
    
    always @(posedge i_clk_out) 
        begin 
                data_meta <=  data_glitchfree; 
                o_data  <=  data_meta; 
        end
endmodule