import ftd3xx
import sys
import struct
if sys.platform == 'win32':
    import _ftd3xx_win32 as _ft
elif sys.platform == 'linux':
    import _ftd3xx_linux as _ft	
import logging

# initialize logging to log in both console and file
logging.basicConfig(filename='datastreaming.log', filemode='w',
    level=logging.DEBUG, format='[%(asctime)s] %(message)s')	
logging.getLogger().addHandler(logging.StreamHandler())

def connect():
    # check connected devices
    numDevices = ftd3xx.createDeviceInfoList()
    if (numDevices == 0):
        logging.debug("ERROR: Please check environment setup! No device is detected.")
        return False
    logging.debug("Detected %d device(s) connected." % numDevices)
    devList = ftd3xx.getDeviceInfoList()	
    devIndex = 0
                
    # open the first device (index 0)
    D3XX = ftd3xx.create(devIndex, _ft.FT_OPEN_BY_INDEX)
    if (D3XX is None):
        logging.debug("ERROR: Please check if another D3XX application is open!")
        return False

    # check if USB3 or USB2		
    devDesc = D3XX.getDeviceDescriptor()
    bUSB3 = devDesc.bcdUSB >= 0x300
    if (bUSB3):
       logging.debug("USB3 :)")
    else:
        logging.debug("Warning: Device is connected using USB2 cable or through USB2 host controller!")

    # validate chip configuration
    cfg = D3XX.getChipConfiguration()

    numChannels = [4, 2, 1, 0, 0]
    channelsToTest = [0]
    numChannels = numChannels[cfg.ChannelConfig]
    if (numChannels == 0):
        numChannels = 1
        if (cfg.ChannelConfig == _ft.FT_CONFIGURATION_CHANNEL_CONFIG_1_OUTPIPE):
            bWrite = True
            bRead = False
        elif (cfg.ChannelConfig == _ft.FT_CONFIGURATION_CHANNEL_CONFIG_1_INPIPE):
            bWrite = False
            bRead = True
    if (cfg.OptionalFeatureSupport &
        _ft.FT_CONFIGURATION_OPTIONAL_FEATURE_ENABLENOTIFICATIONMESSAGE_INCHALL):
        logging.debug("invalid chip configuration: notification callback is set")	
        D3XX.close()
        return False

    # delete invalid channels		
    for channel in range(len(channelsToTest)-1, -1, -1):
        if (channelsToTest[channel] >= numChannels):
            del channelsToTest[channel]	
    if (len(channelsToTest) == 0):
        D3XX.close()
        return
    return D3XX

    
D3XX = connect()

size = 1024*1024*1
#size = 1024
# prepare data to loopback
#dataBuffer = bytearray(size)
#for i in range(size):
#    dataBuffer[i] = 1 << (i%8)
#dataBuffer[:] = itertools.repeat(0x8040201008040201, len(dataBuffer))
#dataBuffer = str(dataBuffer)
pipe = 0

#D3XX.writePipe(pipe, dataBuffer, size, 1000)
while(True):
    read = D3XX.readPipeEx(pipe, size, 1, True)
    data = read['bytes']
    size_read = read['bytesTransferred']

    fmt = "<%dI" % (len(data) // 4)
    new_list = list(struct.unpack(fmt, data))

    for word in new_list:
        try:
            if word != (previous_word << 1) % 0xffffffff:
                print('error!', word, previous_word)
        except:
            pass
        previous_word = word




# check status of writing data
status = D3XX.getLastError()
if (status != 0):
    logging.debug("Write[%#04X] error status %d (%s)" %
        (pipe, status, ftd3xx.getStrError(status)))
    CancelPipe(D3XX, pipe)
    result = False
D3XX.close()