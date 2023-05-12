create_clock -name i_ftdi_clk -period 10 [get_ports {i_ftdi_clk}]

# Constrain the input I/O path
set_input_delay -clock [get_clocks i_ftdi_clk] -max 7 [get_ports {i_ftdi_rxf_n}]
set_input_delay -clock [get_clocks i_ftdi_clk] -min 3.5 [get_ports {i_ftdi_rxf_n}]

set_input_delay -clock [get_clocks i_ftdi_clk] -max 7 [get_ports {io_ftdi_be[*] io_ftdi_data[*]}]
set_input_delay -clock [get_clocks i_ftdi_clk] -min 3.5 [get_ports {io_ftdi_be[*] io_ftdi_data[*]}]

# Constrain the output I/O path
set output_ports {{o_ftdi_wr_n} {o_ftdi_rd_n} {o_ftdi_oe_n} {io_ftdi_be[*]} {io_ftdi_data[*]}};   # list of output ports

set tsu          1.00;            # destination device setup time requirement
set thd          4.80;            # destination device hold time requirement
set trce_dly_max 0.23;            # maximum board trace delay 38mm
set trce_dly_min 0.059;            # minimum board trace delay 10mm ~2.5in*170ps/in

set_output_delay -clock [get_clocks i_ftdi_clk] -max [expr $trce_dly_max \+ $tsu] [get_ports $output_ports];
set_output_delay -clock [get_clocks i_ftdi_clk] -min [expr $trce_dly_min - $thd] [get_ports $output_ports];