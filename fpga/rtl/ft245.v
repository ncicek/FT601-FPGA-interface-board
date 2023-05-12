module ft245_transmitter (i_reset,
            i_ftdi_clk, i_ftdi_txe_n, i_ftdi_rxf_n,
            io_ftdi_data, io_ftdi_be, o_ftdi_oe_n, o_ftdi_wr_n, o_ftdi_rd_n, o_serial_out, o_leds_n, o_ftdi_reset_n, o_fsm);
    input wire i_ftdi_clk, i_reset;
    input wire i_ftdi_txe_n, i_ftdi_rxf_n;
    inout wire [3:0] io_ftdi_be;
    inout wire [31:0] io_ftdi_data;
    output reg o_ftdi_wr_n = 1;
	output wire o_ftdi_oe_n;
	output reg o_ftdi_rd_n = 1;
	output wire [7:0] o_leds_n;
	output reg o_serial_out;
	output wire o_ftdi_reset_n;
	output wire [3:0] o_fsm;

	localparam STATE_IDLE = 0;
	localparam STATE_TRANSMIT_1 = 1;
	localparam STATE_ADDRESS_READ = 2;
	localparam STATE_DATA_READ = 3;
	localparam STATE_DECODE_CMD = 4;
	localparam STATE_TRANSMIT_2 = 5;
	localparam STATE_TRANSMIT_3 = 6;


	assign io_ftdi_be = 4'b1111;
	assign o_ftdi_reset_n = !i_reset;
	
	wire fifo_full; //we are dropping data when this is high
	wire [31:0] fifo_output_data;
	
	reg [31:0] data = 0;
	always @(posedge i_ftdi_clk or posedge i_reset) begin
		if (i_reset) begin
			data <= 0;
		end else begin
			if (!fifo_full) begin
				data <= data + 1;
			end
		end
	end
	/*sfifo 
	#(
		.BW                (32                ),
		.LGFLEN            (4          )
	)
	u_sfifo(
		.i_clk                (i_ftdi_clk                ),
		.i_reset              (i_reset              ),
		.i_wr                 (!fifo_full),
		.i_data               (data               ),
		.o_full               (fifo_full               ),
		.o_fill               (               ),
		.i_rd                 ((!i_ftdi_txe_n) && (fsm == STATE_TRANSMIT || fsm == STATE_TRANSMIT_2)),
		.o_data               (fifo_output_data),
		.o_empty              (              )
	);*/

	assign fifo_output_data[31:0] = data[31:0];
	assign fifo_full = 0;

	assign o_ftdi_oe_n = o_ftdi_rd_n; //allow slave to drive io_ftdi_data bus when we are reading
	assign io_ftdi_data = o_ftdi_oe_n ? fifo_output_data : 32'bZ;
	
	//Register definitions
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

	reg [30:0] dwords_to_transmit;

	//Sequence: send two dwords to bus master
	//DWORD0[31] = READ/WRITE (0/1)
	//DWORD0[3:0] = ADDRESS
	//DWORD1[31:0] = DATA

	reg [3:0] fsm = STATE_IDLE;
	assign o_fsm = fsm;
	always @(posedge i_ftdi_clk or posedge i_reset) begin //reset stops the ftdi_clk so need be sensitive to both edges
		if (i_reset) begin
			fsm <= STATE_IDLE;
			reg_mode <= MODE_IDLE << 31;
		end else begin
			case (fsm)
				STATE_IDLE: begin //Listen state, wait for a command from host
					if (i_ftdi_rxf_n == 0) begin //got data from host, go handle that
						fsm <= STATE_ADDRESS_READ;
					end else if (reg_mode[31] == MODE_STREAM) begin //stream mode enabled
						fsm <= STATE_TRANSMIT_1;
					end
				end

				STATE_TRANSMIT_1: begin //dumping data to the host
					dwords_to_transmit <= 0;
					fsm <= STATE_TRANSMIT_2;
				end

				STATE_TRANSMIT_2: begin //dumping data to the host
					if (dwords_to_transmit >= reg_mode[29:0]) begin
						fsm <= STATE_IDLE;
						reg_mode[31] <= MODE_IDLE; //reset the transmission after a transmit dump
					end else begin
						fsm <= STATE_TRANSMIT_3;
					end
				end

				STATE_TRANSMIT_3: begin //dumping data to the host step 2 of pipeline
					if (i_ftdi_txe_n == 0) begin //when tx buffer is has space, we transfer
						dwords_to_transmit <= dwords_to_transmit + 2;
					end
					fsm <= STATE_TRANSMIT_2;
				end


				STATE_ADDRESS_READ: begin //read first dword which is address
					register_address <= io_ftdi_data[3:0];
					register_access <= io_ftdi_data[31];
					fsm <= STATE_DATA_READ;
				end

				STATE_DATA_READ: begin //read second dword which is data
					register_data <= io_ftdi_data;
					fsm <= STATE_DECODE_CMD;
				end

				STATE_DECODE_CMD: begin
					if (register_access == REG_WRITE) begin
						if (register_address == REG_ADDR_TEST) begin
							//reg_test <= register_data;
						end else if (register_address == REG_ADDR_MODE) begin
							reg_mode <= register_data;
						end
					end
					if (i_ftdi_rxf_n == 1) begin //wait for rx buffer to flush before returning to idle
						fsm <= STATE_IDLE;
					end
				end

				default: begin
					fsm <= STATE_IDLE;
				end
			endcase
		end
	end


	always @(*) begin
		case (fsm)
			STATE_IDLE: begin
				o_ftdi_rd_n = 1;
				o_ftdi_wr_n = 1;
			end
			
			STATE_TRANSMIT_1: begin
				o_ftdi_rd_n = 1;
				o_ftdi_wr_n = 0;
			end

			STATE_TRANSMIT_2: begin
				o_ftdi_rd_n = 1;
				o_ftdi_wr_n = 0;
			end

			STATE_TRANSMIT_3: begin
				o_ftdi_rd_n = 1;
				o_ftdi_wr_n = 0;
			end

			STATE_ADDRESS_READ: begin
				o_ftdi_rd_n = 0;
				o_ftdi_wr_n = 1;
			end

			STATE_DATA_READ: begin
				o_ftdi_rd_n = 0;
				o_ftdi_wr_n = 1;
			end

			STATE_DECODE_CMD: begin
				o_ftdi_rd_n = 1;
				o_ftdi_wr_n = 1;
			end

			default: begin
				o_ftdi_rd_n = 1;
				o_ftdi_wr_n = 1;
			end
		endcase
	end

	`ifdef COCOTB_SIM
		initial begin
		$dumpfile ("ft245_transmitter.vcd");
		$dumpvars (0, ft245_transmitter);
		#1;
		end
	`endif

endmodule

/*module ft245_reciever (i_reset,
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
*/
