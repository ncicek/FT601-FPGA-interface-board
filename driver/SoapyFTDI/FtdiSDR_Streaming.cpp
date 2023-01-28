#include "SoapyFtdiSDR.hpp"
#include <SoapySDR/Logger.hpp>
#include <SoapySDR/Formats.hpp>
#include <SoapySDR/Time.hpp>

#include <memory>
#include <iostream>
#include <cstdint>
#include <cstring>

#include <thread>


extern "C" void cb_init(circular_buffer *cb, size_t capacity, size_t sz);
extern "C" int cb_push_back(circular_buffer *cb, const void *item);
extern "C" int cb_pop_front(circular_buffer *cb, void *item);

circular_buffer cb;
bool do_exit = false;

static std::thread read_thread;

void cb_init(circular_buffer *cb, size_t capacity, size_t sz)
{
    cb->buffer = malloc(capacity * sz);
    cb->buffer_end = (char *)cb->buffer + capacity * sz;
    cb->capacity = capacity;
    cb->count = 0;
    cb->sz = sz;
    cb->head = cb->buffer;
    cb->tail = cb->buffer;
}

int cb_push_back(circular_buffer *cb, const void *item)
{
  void *new_head = (char *)cb->head + cb->sz;
  //printf("new_head=%d tail=%d\n", new_head, cb->tail);

  if (new_head == cb->buffer_end) {
      new_head = cb->buffer;
  }
  if (new_head == cb->tail) {
    return 1;
  }
  memcpy(cb->head, item, cb->sz);
  cb->head = new_head;
  return 0;
}

int cb_pop_front(circular_buffer *cb, void *item)
{
  void *new_tail = cb->tail + cb->sz;
  if (cb->head == cb->tail) {
    return 1;
  }
  memcpy(item, cb->tail, cb->sz);
  if (new_tail == cb->buffer_end) {
    new_tail = cb->buffer;
  }
  cb->tail = new_tail;
  return 0;
}

#define SOAPY_NATIVE_FORMAT SOAPY_SDR_U8

std::vector<std::string> SoapyFtdiSDR::getStreamFormats(const int direction, const size_t channel) const {
    std::vector<std::string> formats;

    //formats.push_back(SOAPY_SDR_CS8);
    //formats.push_back(SOAPY_SDR_CS16);
    formats.push_back(SOAPY_SDR_CF32);

    return formats;
}

std::string SoapyFtdiSDR::getNativeStreamFormat(const int direction, const size_t channel, double &fullScale) const {
    //check that direction is SOAPY_SDR_RX
     if (direction != SOAPY_SDR_RX) {
         throw std::runtime_error("RTL-SDR is RX only, use SOAPY_SDR_RX");
     }

     fullScale = 128;
     return SOAPY_SDR_CF32;
}

SoapySDR::ArgInfoList SoapyFtdiSDR::getStreamArgsInfo(const int direction, const size_t channel) const {
    //check that direction is SOAPY_SDR_RX
     if (direction != SOAPY_SDR_RX) {
         throw std::runtime_error("RTL-SDR is RX only, use SOAPY_SDR_RX");
     }

    SoapySDR::ArgInfoList streamArgs;

    SoapySDR::ArgInfo bufflenArg;
    bufflenArg.key = "bufflen";
    bufflenArg.value = std::to_string(DEFAULT_BUFFER_LENGTH);
    bufflenArg.name = "Buffer Size";
    bufflenArg.description = "Number of bytes per buffer, multiples of 512 only.";
    bufflenArg.units = "bytes";
    bufflenArg.type = SoapySDR::ArgInfo::INT;

    streamArgs.push_back(bufflenArg);

    SoapySDR::ArgInfo buffersArg;
    buffersArg.key = "buffers";
    buffersArg.value = std::to_string(DEFAULT_NUM_BUFFERS);
    buffersArg.name = "Ring buffers";
    buffersArg.description = "Number of buffers in the ring.";
    buffersArg.units = "buffers";
    buffersArg.type = SoapySDR::ArgInfo::INT;

    streamArgs.push_back(buffersArg);

    SoapySDR::ArgInfo asyncbuffsArg;
    asyncbuffsArg.key = "asyncBuffs";
    asyncbuffsArg.value = "0";
    asyncbuffsArg.name = "Async buffers";
    asyncbuffsArg.description = "Number of async usb buffers (advanced).";
    asyncbuffsArg.units = "buffers";
    asyncbuffsArg.type = SoapySDR::ArgInfo::INT;

    streamArgs.push_back(asyncbuffsArg);

    return streamArgs;
}

/*******************************************************************
 * Async thread work
 ******************************************************************/

static void ftdi_reader(FT_HANDLE handle)
{
	std::unique_ptr<uint8_t[]> raw_buf(new uint8_t[DEFAULT_BUFFER_LENGTH*4]);

    std::complex<float> cf32_buf[DEFAULT_BUFFER_LENGTH];

	while (!do_exit) {
        ULONG count = 0;
        if (FT_OK != FT_ReadPipeEx(handle, 0,
                    raw_buf.get(), DEFAULT_BUFFER_LENGTH*4, &count, 1000)) {
            do_exit = true;
            break;
        }

        for (uint32_t i = 0; i < (DEFAULT_BUFFER_LENGTH); i++) {
            uint32_t dword = 0;
            for (uint8_t j = 0; j < 4; j++) {
                dword |= raw_buf[i * 4 + j] << (j * 8);
            }
            cf32_buf[i] = dword;
        }

        cb_push_back(&cb, cf32_buf);
	}
	printf("Read stopped\r\n");
}

SoapySDR::Stream *SoapyFtdiSDR::setupStream(
        const int direction,
        const std::string &format,
        const std::vector<size_t> &channels,
        const SoapySDR::Kwargs &args)
{

    if (direction != SOAPY_SDR_RX)
    {
        throw std::runtime_error("RTL-SDR is RX only, use SOAPY_SDR_RX");
    }

    //check the channel configuration
    if (channels.size() > 1 or (channels.size() > 0 and channels.at(0) != 0))
    {
        throw std::runtime_error("setupStream invalid channel selection");
    }

    //check the format
    if (format == SOAPY_SDR_CF32)
    {
        SoapySDR_log(SOAPY_SDR_INFO, "Using format CF32.");
        rxFormat = RTL_RX_FORMAT_FLOAT32;
    }
    /*else if (format == SOAPY_SDR_CS16)
    {
        SoapySDR_log(SOAPY_SDR_INFO, "Using format CS16.");
        rxFormat = RTL_RX_FORMAT_INT16;
    }
    else if (format == SOAPY_SDR_CS8) {
        SoapySDR_log(SOAPY_SDR_INFO, "Using format CS8.");
        rxFormat = RTL_RX_FORMAT_INT8;
    }*/
    else
    {
        throw std::runtime_error(
                "setupStream invalid format '" + format
                        + "' -- Only CS8, CS16 and CF32 are supported by SoapyFtdiSDR module.");
    }

    bufferType = SoapySDR::formatToSize(format);

    bufferLength = DEFAULT_BUFFER_LENGTH;
    if (args.count("bufflen") != 0)
    {
        try
        {
            int bufferLength_in = std::stoi(args.at("bufflen"));
            if (bufferLength_in > 0)
            {
                bufferLength = bufferLength_in;
            }
        }
        catch (const std::invalid_argument &){}
    }
    SoapySDR_logf(SOAPY_SDR_DEBUG, "RTL-SDR Using buffer length %d", bufferLength);

    numBuffers = DEFAULT_NUM_BUFFERS;
    if (args.count("buffers") != 0)
    {
        try
        {
            int numBuffers_in = std::stoi(args.at("buffers"));
            if (numBuffers_in > 0)
            {
                numBuffers = numBuffers_in;
            }
        }
        catch (const std::invalid_argument &){}
    }
    SoapySDR_logf(SOAPY_SDR_DEBUG, "RTL-SDR Using %d buffers", numBuffers);

    asyncBuffs = 0;
    if (args.count("asyncBuffs") != 0)
    {
        try
        {
            int asyncBuffs_in = std::stoi(args.at("asyncBuffs"));
            if (asyncBuffs_in > 0)
            {
                asyncBuffs = asyncBuffs_in;
            }
        }
        catch (const std::invalid_argument &){}
    }

    cb_init(&cb, numBuffers, bufferLength*bufferType);
    return (SoapySDR::Stream *) this;
}

int SoapyFtdiSDR::activateStream(
        SoapySDR::Stream *stream,
        const int flags,
        const long long timeNs,
        const size_t numElems)
{
    if (flags != 0) return SOAPY_SDR_NOT_SUPPORTED;
    resetBuffer = true;
    bufferedElems = 0;

    FT_STATUS status = FT_SetStreamPipe(dev,FALSE,TRUE,0x82, (numElems == 0 ? DEFAULT_BUFFER_LENGTH: numElems));
    if (status != 0) {
        throw std::runtime_error("FT_SetStreamPipe failed");
    }
    //start the async thread
    read_thread = std::thread(ftdi_reader, dev);


    return 0;
}

void SoapyFtdiSDR::closeStream(SoapySDR::Stream *stream)
{
    this->deactivateStream(stream, 0, 0);
    free(cb.buffer);
}

int SoapyFtdiSDR::deactivateStream(SoapySDR::Stream *stream, const int flags, const long long timeNs)
{
    if (flags != 0) return SOAPY_SDR_NOT_SUPPORTED;
    if (read_thread.joinable())
    {
        read_thread.join();
    }
    return 0;
}

int SoapyFtdiSDR::readStream(
        SoapySDR::Stream *stream,
        void * const *buffs,
        const size_t numElems,
        int &flags,
        long long &timeNs,
        const long timeoutUs)
{
    //this is the user's buffer for channel 0
    void *buff0 = buffs[0];

    uint32_t i;
    uint32_t readElems = 0;
    for (i = 0; i < (numElems/bufferLength); i++){
        if (cb_pop_front(&cb, buff0+bufferLength*bufferType*i) == 1) {
        //if (cb_pop_front(&cb, buff0) == 1) {
            printf("underflow\n");
        } else {
            readElems++;
        }
    }
    return readElems*bufferLength;
}

int SoapyFtdiSDR::readStreamStatus(
		SoapySDR::Stream *stream,
		size_t &chanMask,
		int &flags,
		long long &timeNs,
		const long timeoutUs)
{
	return SOAPY_SDR_NOT_SUPPORTED;
}

