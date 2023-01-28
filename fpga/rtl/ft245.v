module ft245_reciever (i_reset,
            i_ftdi_clk, slow_clock, i_ftdi_txe_n, i_ftdi_rxf_n,
            io_ftdi_data, io_ftdi_be, o_ftdi_oe_n, o_ftdi_wr_n, o_ftdi_rd_n, o_serial_out, o_leds_n, o_ftdi_reset_n, o_fsm);
    input wire i_ftdi_clk, slow_clock, i_reset;
    input wire i_ftdi_txe_n, i_ftdi_rxf_n;
    inout wire [3:0] io_ftdi_be;
    inout wire [31:0] io_ftdi_data;
    output wire o_ftdi_wr_n;
	output reg o_ftdi_oe_n = 1;
	output reg o_ftdi_rd_n = 1;
	output wire [7:0] o_leds_n;
	output reg o_serial_out;
	output wire o_ftdi_reset_n;
	output wire [3:0] o_fsm;

	

	assign o_ftdi_reset_n = !i_reset;

	//constant read mode
	assign o_ftdi_wr_n = 1;	
	
	//div 2MHz
	reg [15:0] divider = 0;
	wire read_enable_stb, read_enable;
	`ifdef COCOTB_SIM
		assign read_enable = divider[1];
	`else
		assign read_enable = divider[1];
	`endif

	pos_edge_det pos_edge_det(read_enable ,slow_clock, read_enable_stb); 
	always @(posedge slow_clock) begin
		divider <= divider + 1;
	end

	
	wire [7:0] o_leds;
	wire [31:0] rd_data;
	assign o_leds = rd_data[7:0];
	assign o_leds_n = ~o_leds;
	wire empty; //set the fifo to trigger this when max-4kilobytes is full

    afifo 
	#(
		.LGFIFO             (10		),
		.WIDTH              (32              ),
		.NFF                (2                )
	)
	u_afifo(
		.i_wclk       (i_ftdi_clk       ),
		.i_wr_reset_n (!i_reset),
		.i_wr         ((~i_ftdi_rxf_n) && (~o_ftdi_rd_n)),
		.i_wr_data    (io_ftdi_data    ),
		.o_wr_full    (    ),
		.i_rclk       (slow_clock       ),
		.i_rd_reset_n (!i_reset),
		.i_rd         (read_enable_stb         ),
		.o_rd_data    (rd_data    ),
		.o_rd_empty   (empty   )
	);

	reg [1:0] fsm = 0;
	assign o_fsm = fsm;
	always @(posedge i_ftdi_clk or posedge i_reset) begin //reset stops the ftdi_clk so need be sensitive to both edges
		if (i_reset) begin
			fsm <= 0;
		end else begin
			case (fsm)
				0: begin//IDLE
					o_ftdi_rd_n <= 1;
					o_ftdi_oe_n <= 1;
					if (i_ftdi_rxf_n == 0) begin
						fsm <= 1;
					end
				end
				1: begin //CHECK FIFO LEVEL
					if (empty) begin //if 4k is available
						o_ftdi_rd_n <= 1;
						o_ftdi_oe_n <= 0; //start accepting data
						fsm <= 2;
					end else begin
						o_ftdi_rd_n <= 1; //wait
						o_ftdi_oe_n <= 1; 
					end
				end

				2: begin //DUMP data
					if (i_ftdi_rxf_n == 1) begin //wait for data dump to complete
						fsm <= 0;
						o_ftdi_rd_n <= 1;
						o_ftdi_oe_n <= 1;
					end else begin
						o_ftdi_rd_n <= 0;
						o_ftdi_oe_n <= 0;
					end
				end
				default: begin
					fsm <= 0;
				end
			endcase
		end
	end
	


	`ifdef COCOTB_SIM
		initial begin
		$dumpfile ("ft245_reciever.vcd");
		$dumpvars (0, ft245_reciever);
		#1;
		end
	`endif

endmodule



module ft245_transmitter (i_reset,
            i_ftdi_clk, slow_clock, i_ftdi_txe_n, i_ftdi_rxf_n,
            io_ftdi_data, io_ftdi_be, o_ftdi_oe_n, o_ftdi_wr_n, o_ftdi_rd_n, o_serial_out, o_leds_n, o_ftdi_reset_n, o_fsm);
    input wire i_ftdi_clk, slow_clock, i_reset;
    input wire i_ftdi_txe_n, i_ftdi_rxf_n;
    inout wire [3:0] io_ftdi_be;
    inout wire [31:0] io_ftdi_data;
    output reg o_ftdi_wr_n;
	output reg o_ftdi_oe_n = 0;
	output reg o_ftdi_rd_n = 1; //leave this at 1 all the time for transmit
	output wire [7:0] o_leds_n;
	output reg o_serial_out;
	output wire o_ftdi_reset_n;
	output wire [3:0] o_fsm;
	
	assign io_ftdi_be = 4'b1111;

	assign o_ftdi_reset_n = !i_reset;
	
	//div 2MHz
	reg [15:0] divider = 0;
	wire read_enable_stb, read_enable;
	`ifdef COCOTB_SIM
		assign read_enable = divider[1];
	`else
		assign read_enable = divider[1];
	`endif

	pos_edge_det pos_edge_det(read_enable ,slow_clock, read_enable_stb); 
	always @(posedge slow_clock) begin
		divider <= divider + 1;
	end

	wire full;
	wire [31:0] fifo_output_data;
	
	reg [31:0] data = 0;
	always @(posedge i_ftdi_clk) begin
		if (!full) begin
			data <= data + 1;
		end
	end

	sfifo 
	#(
		.BW                (32                ),
		.LGFLEN            (9          )
	)
	u_sfifo(
		.i_clk                (i_ftdi_clk                ),
		.i_reset              (i_reset              ),
		.i_wr                 (!full),
		.i_data               (data               ),
		.o_full               (full               ),
		.o_fill               (               ),
		.i_rd                 ((!i_ftdi_txe_n) && (!o_ftdi_wr_n)),
		.o_data               (fifo_output_data),
		.o_empty              (              )
	);
	
	//io_ftdi_data arbiter, master drives it when oe_n is high
	assign io_ftdi_data = o_ftdi_oe_n ? fifo_output_data : 32'bZ;
	
	localparam REG_ADDR_TEST = 0;
	localparam REG_ADDR_MODE = 1;

	localparam REG_READ = 0;
	localparam REG_WRITE = 1;

	localparam MODE_STREAM = 1;
	localparam MODE_IDLE = 0;

	reg[31:0] reg_test = 32'hDEADBEEF; //read only test reg
	reg[31:0] reg_mode = MODE_IDLE << 31;

	wire [7:0] o_leds;
	assign o_leds = data[23:16];
	assign o_leds_n = ~o_leds;

	reg [3:0] register_address;
	reg [31:0] register_data;
	reg register_access = REG_READ;

	reg [30:0] bytes_to_read;

	//Sequence: send two dwords to bus master
	//DWORD0[31] = READ/WRITE (0/1)
	//DWORD0[3:0] = ADDRESS
	//DWORD1[31:0] = DATA

	reg [3:0] fsm = 0;
	assign o_fsm = fsm;
	always @(posedge i_ftdi_clk or posedge i_reset) begin //reset stops the ftdi_clk so need be sensitive to both edges
		if (i_reset) begin
			fsm <= 0;
			o_ftdi_oe_n <= 0;
			o_ftdi_rd_n <= 1;
			o_ftdi_wr_n <= 1;
		end else begin
			case (fsm)
				0: begin //Listen, wait for command from host
					o_ftdi_oe_n <= 0;
					o_ftdi_rd_n <= 1;
					o_ftdi_wr_n <= 1;

					if (reg_mode[31] == MODE_STREAM) begin
						bytes_to_read <= reg_mode[30:0];
						fsm <= 1;
					end else begin
						if (i_ftdi_rxf_n == 0) begin //got data from host
							fsm <= 3;
						end
					end
				end

				1: begin //Want to stream, check if host ready to accept
					if (i_ftdi_txe_n == 0) begin
						fsm <= 2;
					end
				end

				2: begin //dumping data to the host
					if (i_ftdi_txe_n == 1) begin
						fsm <= 1;
					end else begin
						o_ftdi_wr_n <= 0;
						bytes_to_read <= bytes_to_read - 4; //4 bytes transferred per dword
						if (bytes_to_read < 4) begin
							fsm <= 0;
						end
					end
				end

				3: begin //make host wait until we are ready to accept a command
					if (1) begin //we are always ready
						o_ftdi_rd_n <= 0;
						o_ftdi_oe_n <= 0; //start accepting data
						fsm <= 4;
					end else begin
						o_ftdi_rd_n <= 1; //wait
						o_ftdi_oe_n <= 1; 
					end
				end

				4: begin //read first dword which is address
					if (i_ftdi_rxf_n == 0) begin
						register_address <= io_ftdi_data[3:0];
						register_access <= io_ftdi_data[31];
						fsm <= 5;
					end else begin
						fsm <= 0;
					end
				end

				5: begin //read second dword which is data
					if (i_ftdi_rxf_n == 0) begin
						register_data <= io_ftdi_data;
						fsm <= 6;
					end else begin
						fsm <= 0;
					end
				end

				6: begin //decode command, write some wishbone register here
					if (register_access == REG_WRITE) begin
						if (register_address == REG_ADDR_TEST) begin
							//reg_test <= register_data;
						end else if (register_address == REG_ADDR_MODE) begin
							reg_mode <= register_data;
						end
					end
					if (i_ftdi_rxf_n == 1) begin //wait for data dump to complete
						fsm <= 0;
					end
				end

				default: begin
					fsm <= 0;
				end
			endcase
		end
	end

	//assign io_ftdi_data = ((!o_ftdi_wr_n) & o_ftdi_oe_n) ? data : 0; //only output when its our turn
	//assign io_ftdi_data = data;
	//assign io_ftdi_data = 32'hF0F0F0F0;


	`ifdef COCOTB_SIM
		initial begin
		$dumpfile ("ft245_transmitter.vcd");
		$dumpvars (0, ft245_transmitter);
		#1;
		end
	`endif

endmodule