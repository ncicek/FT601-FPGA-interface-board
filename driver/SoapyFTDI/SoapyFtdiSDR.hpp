#include <vector>
#include <mutex>
#include <chrono>
#include <atomic>
#include <condition_variable>
#include <SoapySDR/Device.hpp>
#include <SoapySDR/Logger.hpp>
#include <SoapySDR/Types.hpp>
#include <SoapySDR/Formats.hpp>
#include <SoapySDR/ConverterRegistry.hpp>
#include "ftd3xx.h"

#define DEFAULT_BUFFER_LENGTH 256 //number of 
#define DEFAULT_NUM_BUFFERS 1024 //number of entries in ring buffer
#define BYTES_PER_SAMPLE 2
#define BYTES_PER_FLOAT (sizeof(float)/sizeof(uint8_t))

#define REG_ADDR_MODE 1
#define MODE_STREAM 1
#define REG_WRITE 1

#define NUM_DWORDS 1073741808 //30 bits

typedef enum rtlsdrRXFormat
{
    RTL_RX_FORMAT_FLOAT32, RTL_RX_FORMAT_INT16, RTL_RX_FORMAT_INT8
} rtlsdrRXFormat;

typedef struct circular_buffer
{
	void *buffer;     // data buffer
	void *buffer_end; // end of data buffer
	size_t capacity;  // maximum number of items in the buffer
	size_t count;     // number of items in the buffer
	size_t sz;        // size of each item in the buffer
	void *head;       // pointer to head
	void *tail;       // pointer to tail
} circular_buffer;

/*
#ifndef C_CODE_H
#define C_CODE_H

extern "C" {
	uint8_t *ftdi_buffer;
	circular_buffer cb;
}

#endif*/


class SoapyFtdiSDR : public SoapySDR::Device{

	public:
		SoapyFtdiSDR( const SoapySDR::Kwargs & args );
		~SoapyFtdiSDR();

		/*******************************************************************
		 * Identification API
		 ******************************************************************/

		std::string getDriverKey( void ) const;


		std::string getHardwareKey( void ) const;


		SoapySDR::Kwargs getHardwareInfo( void ) const;


		/*******************************************************************
		 * Channels API
		 ******************************************************************/

		size_t getNumChannels( const int ) const;


		//bool getFullDuplex( const int direction, const size_t channel ) const;

		/*******************************************************************
		 * Stream API
		 ******************************************************************/

		std::vector<std::string> getStreamFormats(const int direction, const size_t channel) const;

		std::string getNativeStreamFormat(const int direction, const size_t channel, double &fullScale) const;

		SoapySDR::ArgInfoList getStreamArgsInfo(const int direction, const size_t channel) const;

		SoapySDR::Stream *setupStream(
				const int direction,
				const std::string &format,
				const std::vector<size_t> &channels = std::vector<size_t>(),
				const SoapySDR::Kwargs &args = SoapySDR::Kwargs() );

		void closeStream( SoapySDR::Stream *stream );

		//size_t getStreamMTU( SoapySDR::Stream *stream ) const;

		int activateStream(
				SoapySDR::Stream *stream,
				const int flags = 0,
				const long long timeNs = 0,
				const size_t numElems = 0 );

		int deactivateStream(
				SoapySDR::Stream *stream,
				const int flags = 0,
				const long long timeNs = 0 );

		int readStream(
				SoapySDR::Stream *stream,
				void * const *buffs,
				const size_t numElems,
				int &flags,
				long long &timeNs,
				const long timeoutUs = 100000 );

		int readStreamStatus(
				SoapySDR::Stream *stream,
				size_t &chanMask,
				int &flags,
				long long &timeNs,
				const long timeoutUs
				);

		/*******************************************************************
		 * Settings API
		 ******************************************************************/

		SoapySDR::ArgInfoList getSettingInfo(void) const;


		void writeSetting(const std::string &key, const std::string &value);


		std::string readSetting(const std::string &key) const;


		/*******************************************************************
		 * Sample Rate API
		 ******************************************************************/

		void setSampleRate( const int direction, const size_t channel, const double rate );


		double getSampleRate( const int direction, const size_t channel ) const;


		std::vector<double> listSampleRates( const int direction, const size_t channel ) const;


		void setBandwidth( const int direction, const size_t channel, const double bw );


		double getBandwidth( const int direction, const size_t channel ) const;


		std::vector<double> listBandwidths( const int direction, const size_t channel ) const;

		//SoapySDR::RangeList getSampleRateRange(const int direction, const size_t channel) const;

	private:
        FT_HANDLE dev;

		//cached settings
		rtlsdrRXFormat rxFormat;
		uint32_t sampleRate, centerFrequency, bandwidth;
		int ppm, directSamplingMode;
		size_t numBuffers, bufferLength, asyncBuffs;

		bool iqSwap, gainMode, offsetMode, digitalAGC, testMode, biasTee;


		

	public:
		//async api usage
		void rx_async_operation(void);
		void rx_callback(unsigned char *buf, uint32_t len);

		signed char *_currentBuff;
		std::atomic<bool> _overflowEvent;
		size_t _currentHandle;
		size_t bufferedElems;
		size_t bufferType;
		std::atomic<bool> resetBuffer;
};
