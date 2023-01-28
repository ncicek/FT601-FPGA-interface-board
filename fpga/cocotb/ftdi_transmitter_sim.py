import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, FallingEdge, RisingEdge
from cocotb.types import Logic


async def reset_dut(dut):
    dut.i_reset.value = 1
    await FallingEdge(dut.i_ftdi_clk)
    dut.i_reset.value = 0
    await FallingEdge(dut.i_ftdi_clk)

async def reset_ftdi(dut):
    dut.i_ftdi_rxf_n.value = 1
    dut.i_ftdi_txe_n.value = 1
    dut.io_ftdi_data.value = 0
    await FallingEdge(dut.i_ftdi_clk)

async def ftdi_usb_data_reader(dut): #usb host writes to ftdi
    #dut.i_ftdi_txe_n.value = Logic('Z')
    #dut.i_ftdi_rxf_n.value = Logic('Z')

    print("waiting")
    await FallingEdge(dut.o_ftdi_reset_n) #wait for master to release us from reset
    print('done waiting')


    #await Timer(60, units="ns")

    while(True):
        await Timer(1000, units="ns") #wait a bit between transactions
        #start a 4k transaction

        await FallingEdge(dut.i_ftdi_clk)
        dut.i_ftdi_txe_n.value = 0 #this tells bus master to start transmitting
        await FallingEdge(dut.o_ftdi_wr_n)
        for word_idx in range(1,1024): #transfer 4KB
            await RisingEdge(dut.i_ftdi_clk)

            data = dut.io_ftdi_data.value

            try:
                assert data == (previous_data << 1) % 0xffffffff
            except NameError:
                pass
            except AssertionError:
                print(data, previous_data)
                raise TestFailure('missing bits')

            previous_data = data
        await FallingEdge(dut.i_ftdi_clk)
        dut.i_ftdi_txe_n.value = 1


async def ftdi_sanity_checker(dut):
    await RisingEdge(dut.i_ftdi_clk)
    assert (~int(dut.o_ftdi_wr_n) and ~int(dut.o_ftdi_rd_n)) != 1 #wr and rd should never be asserted at the same time


async def ftdi_write(dut, data_array): #usb host writes to ftdi
    await FallingEdge(dut.i_ftdi_clk)
    dut.i_ftdi_rxf_n.value = 0
    await FallingEdge(dut.o_ftdi_rd_n)

    for data in data_array:
        dut.io_ftdi_data.value = data
        await RisingEdge(dut.i_ftdi_clk)

    dut.i_ftdi_rxf_n.value = 1


@cocotb.test()
async def ftdi_transmitter_sim(dut):
    clk_2mhz   = Clock(dut.slow_clock, 50, units='ns')
    clk_100mhz = Clock(dut.i_ftdi_clk, 10, units='ns')
    clk_gen1 = cocotb.start_soon(clk_2mhz.start())
    clk_gen2 = cocotb.start_soon(clk_100mhz.start())

    print('done reset')
    
    await cocotb.start(reset_ftdi(dut))
    await cocotb.start(reset_dut(dut))
    await FallingEdge(dut.i_ftdi_clk)
    cocotb.start(ftdi_sanity_checker(dut))

    await cocotb.start(ftdi_write(dut, [(1<<31)|1, 1]))
    ftdi_thread = cocotb.start(ftdi_usb_data_reader(dut))

    #await ftdi_thread
    await Timer(10, units="us")
    #await adc_data_streamer(dut)