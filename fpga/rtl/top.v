module top (i_reset_n, i_ftdi_clk, i_ftdi_txe_n, i_ftdi_rxf_n,
            io_ftdi_data, io_ftdi_be, o_ftdi_oe_n, o_ftdi_wr_n, o_ftdi_rd_n, o_serial_out, o_leds_n, o_ftdi_reset_n, debug);
    input wire i_reset_n /* synthesis syn_force_pads = 1*/;
	input wire i_ftdi_clk /* synthesis syn_force_pads = 1*/;
    input wire i_ftdi_txe_n, i_ftdi_rxf_n /* synthesis syn_force_pads = 1*/;
    inout wire [3:0] io_ftdi_be;
    inout wire [31:0] io_ftdi_data;
    output wire o_ftdi_wr_n /* synthesis syn_force_pads = 1*/;
	output wire o_ftdi_oe_n /* synthesis syn_force_pads = 1*/;
	output wire o_ftdi_rd_n /* synthesis syn_force_pads = 1*/;
	output wire [7:0] o_leds_n /* synthesis syn_force_pads = 1*/;
	output wire o_serial_out /* synthesis syn_force_pads = 1*/;
	output wire o_ftdi_reset_n /* synthesis syn_force_pads = 1*/;
	output wire [3:0] debug /* synthesis syn_force_pads = 1*/;
	

	/*wire slow_clock;
	OSCH OSCinst0 (.STDBY(1'b0),.OSC(slow_clock),.SEDSTDBY());
	defparam OSCinst0.NOM_FREQ = "88.67" ;*/
	
	wire reset;
	assign reset = !i_reset_n;
	
	assign o_serial_out = i_reset_n;

	PUR PUR_INST (.PUR (reset));
	defparam PUR_INST.RST_PULSE = 200;
	

	ft245_transmitter u_ft245(
		.i_ftdi_clk   (i_ftdi_clk   ),
		.i_reset      (reset    ),
		.i_ftdi_txe_n (i_ftdi_txe_n ),
		.i_ftdi_rxf_n (i_ftdi_rxf_n ),
		.io_ftdi_be   (io_ftdi_be   ),
		.io_ftdi_data (io_ftdi_data ),
		.o_ftdi_wr_n  (o_ftdi_wr_n  ),
		.o_ftdi_oe_n  (o_ftdi_oe_n  ),
		.o_ftdi_rd_n  (o_ftdi_rd_n  ),
		.o_leds_n     (o_leds_n     ),
		.o_serial_out ( ),
		.o_ftdi_reset_n (o_ftdi_reset_n),
		.o_fsm(debug)
	);
	
endmodule

