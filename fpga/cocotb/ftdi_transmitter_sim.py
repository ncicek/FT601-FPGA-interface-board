import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, FallingEdge, RisingEdge
from cocotb.types import Logic

#Regs
REG_ADDR_MODE = 1
MODE_STREAM = 1

REG_WRITE = 1


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


async def ftdi_usb_data_recieve(dut, dwords_per_transfer): #usb host writes to ftdi
    await FallingEdge(dut.i_ftdi_clk)
    dut.i_ftdi_txe_n.value = 0 #this asks bus master to start transmitting
    await FallingEdge(dut.o_ftdi_wr_n)

    recieved_data = [None] * dwords_per_transfer
    for word_idx in range(dwords_per_transfer): #transfer 4KB
        await RisingEdge(dut.i_ftdi_clk)

        data = int(dut.io_ftdi_data.value)
        
        print(data)

        try:
            assert data == previous_data + 1
        except NameError:
            pass
        except AssertionError:
            print(data, previous_data)
            raise TestFailure("failed")

        previous_data = data
        recieved_data[word_idx] = data

    await FallingEdge(dut.i_ftdi_clk)
    dut.i_ftdi_txe_n.value = 1
    


async def ftdi_sanity_checker(dut):
    await RisingEdge(dut.i_ftdi_clk)
    assert (~int(dut.o_ftdi_wr_n) and ~int(dut.o_ftdi_rd_n)) != 1 #wr and rd should never be asserted at the same time


async def write_reg(dut, addr, data):
    #print(hex(addr), hex(data))
    await cocotb.start(ftdi_write(dut, [(REG_WRITE<<31)|addr, data]))

async def ftdi_write(dut, data_array): #usb host writes to ftdi
    await FallingEdge(dut.i_ftdi_clk)
    dut.i_ftdi_rxf_n.value = 0
    await FallingEdge(dut.o_ftdi_rd_n)

    for data in data_array:
        dut.io_ftdi_data.value = data
        await RisingEdge(dut.i_ftdi_clk)
        #print("DATA =", hex(data))

    dut.i_ftdi_rxf_n.value = 1


@cocotb.test()
async def ftdi_transmitter_sim(dut):
    clk_100mhz = Clock(dut.i_ftdi_clk, 10, units='ns')
    clk_gen2 = cocotb.start_soon(clk_100mhz.start())
    
    await cocotb.start_soon(reset_ftdi(dut))
    await cocotb.start_soon(reset_dut(dut))
    await FallingEdge(dut.i_ftdi_clk)
    cocotb.start_soon(ftdi_sanity_checker(dut))

    #configure the read
    dwords_per_transfer = 128
    await cocotb.start_soon(write_reg(dut, REG_ADDR_MODE, MODE_STREAM<<31 | dwords_per_transfer))
    #perform a couple reads
    number_of_transfers = 2
    for i in range(number_of_transfers):
        await cocotb.start_soon(ftdi_usb_data_recieve(dut, dwords_per_transfer))

    #disable the read, configure back to idle mode
    await cocotb.start_soon(write_reg(dut, REG_ADDR_MODE, 0))

    #configure another read
    dwords_per_transfer = 32
    await cocotb.start_soon(write_reg(dut, REG_ADDR_MODE, MODE_STREAM<<31 | dwords_per_transfer))
    #perform a couple reads
    number_of_transfers = 5
    for i in range(number_of_transfers):
        await cocotb.start_soon(ftdi_usb_data_recieve(dut, dwords_per_transfer))

    await Timer(5, units="us")
    #await adc_data_streamer(dut)