import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, FallingEdge, RisingEdge
from cocotb.types import Logic


async def reset_dut(dut):
    dut.i_reset.value = 1
    await FallingEdge(dut.i_ftdi_clk)
    dut.i_reset.value = 0
    await FallingEdge(dut.i_ftdi_clk)

async def ftdi_usb_data_writer(dut): #usb host writes to ftdi
    dut.i_ftdi_txe_n.value = Logic('Z')
    dut.i_ftdi_rxf_n.value = Logic('Z')

    print("waiting")
    await RisingEdge(dut.o_ftdi_reset_n) #wait for master to release us from reset
    print('done waiting')


    #await Timer(60, units="ns")

    while(True):
        await Timer(10, units="ns") #wait a bit between transactions
        #start a 4k transaction
        await RisingEdge(dut.i_ftdi_clk)
        assert int(dut.o_ftdi_wr_n) | int(dut.o_ftdi_rd_n) != 0 #wr and rd should never be asserted at the same time

        dut.i_ftdi_rxf_n.value = 0
        await FallingEdge(dut.o_ftdi_oe_n)
        dut.io_ftdi_data.value = 1
        await FallingEdge(dut.o_ftdi_rd_n)

        for word_idx in range(1,1024): #transfer 4KB
            dut.io_ftdi_data.value = word_idx + 1
            await RisingEdge(dut.i_ftdi_clk)
            

        dut.i_ftdi_rxf_n.value = 1




@cocotb.test()
async def ftdi_sim(dut):
    clk_2mhz   = Clock(dut.slow_clock, 50, units='ns')
    clk_100mhz = Clock(dut.i_ftdi_clk, 10, units='ns')
    clk_gen1 = cocotb.start_soon(clk_2mhz.start())
    clk_gen2 = cocotb.start_soon(clk_100mhz.start())

    print('done reset')

    #start the adc streamer
    #cocotb.fork(adc_data_streamer(dut))
    ftdi_thread = cocotb.start(ftdi_usb_data_writer(dut))
    reset_thread = cocotb.start(reset_dut(dut))
    await reset_thread

    await ftdi_thread
    await Timer(500, units="us")
    #await adc_data_streamer(dut)