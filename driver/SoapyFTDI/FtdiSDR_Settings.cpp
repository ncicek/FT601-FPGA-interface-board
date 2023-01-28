#include "SoapyFtdiSDR.hpp"
#include <SoapySDR/Time.hpp>
#include <cstring>

static void turn_off_thread_safe(void)
{
	FT_TRANSFER_CONF conf;

	memset(&conf, 0, sizeof(FT_TRANSFER_CONF));
	conf.wStructSize = sizeof(FT_TRANSFER_CONF);
	conf.pipe[FT_PIPE_DIR_IN].fNonThreadSafeTransfer = true;
	conf.pipe[FT_PIPE_DIR_OUT].fNonThreadSafeTransfer = true;
	for (DWORD i = 0; i < 4; i++)
		FT_SetTransferParams(&conf, i);
}

SoapyFtdiSDR::SoapyFtdiSDR( const SoapySDR::Kwargs &args )
{
	unsigned int num_devices;
    FT_DEVICE_DESCRIPTOR descriptor;
    FT_CreateDeviceInfoList(&num_devices);
    if (num_devices == 0) {
        printf("Could not find ftdi device\n");
        return;
    }

    turn_off_thread_safe();
    
	FT_Create(0, FT_OPEN_BY_INDEX, &dev);
    FT_GetDeviceDescriptor(dev, &descriptor);
    if (descriptor.bcdUSB >= 0x300) {
        printf("USB3.1\n");
    } else {
        printf("USB2.0\n");
    }

	if (dev == 0) {
        SoapySDR_logf(SOAPY_SDR_ERROR, "Could not find ftdi device");
    }
}

SoapyFtdiSDR::~SoapyFtdiSDR(void){
	FT_Close(dev);
}

/*******************************************************************
 * Identification API
 ******************************************************************/

std::string SoapyFtdiSDR::getDriverKey( void ) const
{
	return "FtdiSDR";
}

std::string SoapyFtdiSDR::getHardwareKey( void ) const
{
	return "Nebi's board";
}

SoapySDR::Kwargs SoapyFtdiSDR::getHardwareInfo( void ) const
{
	SoapySDR::Kwargs info;
	return info;
}


/*******************************************************************
 * Channels API
 ******************************************************************/

size_t SoapyFtdiSDR::getNumChannels( const int dir ) const
{
	return (dir == SOAPY_SDR_RX) ? 1 : 0;
}


/*******************************************************************
 * Settings API
 ******************************************************************/

SoapySDR::ArgInfoList SoapyFtdiSDR::getSettingInfo(void) const
{
	SoapySDR::ArgInfoList setArgs;

	return setArgs;
}

void SoapyFtdiSDR::writeSetting(const std::string &key, const std::string &value)
{
}


std::string SoapyFtdiSDR::readSetting(const std::string &key) const
{
	std::string info;
	return info;
}

/*******************************************************************
 * Sample Rate API
 ******************************************************************/

void SoapyFtdiSDR::setSampleRate(const int direction, const size_t channel, const double rate)
{
    //long long ns = SoapySDR::ticksToTimeNs(ticks, sampleRate);
    sampleRate = rate;
    resetBuffer = true;
    SoapySDR_logf(SOAPY_SDR_DEBUG, "Setting sample rate: %d", sampleRate);
    /*int r = rtlsdr_set_sample_rate(dev, sampleRate);
    if (r == -EINVAL)
    {
        throw std::runtime_error("setSampleRate failed: RTL-SDR does not support this sample rate");
    }
    if (r != 0)
    {
        throw std::runtime_error("setSampleRate failed");
    }*/
    //sampleRate = rtlsdr_get_sample_rate(dev);
    //ticks = SoapySDR::timeNsToTicks(ns, sampleRate);
}

double SoapyFtdiSDR::getSampleRate(const int direction, const size_t channel) const
{
    return sampleRate;
}

std::vector<double> SoapyFtdiSDR::listSampleRates( const int direction, const size_t channel ) const
{
	std::vector<double> options;

	options.push_back(100e6);
	return(options);
}


void SoapyFtdiSDR::setBandwidth( const int direction, const size_t channel, const double bw )
{

}

double SoapyFtdiSDR::getBandwidth( const int direction, const size_t channel ) const
{
    long long bandwidth = 0;
	return double(bandwidth);
}

std::vector<double> SoapyFtdiSDR::listBandwidths( const int direction, const size_t channel ) const
{
	std::vector<double> options;
	options.push_back(0.2e6);
	options.push_back(1e6);
	options.push_back(2e6);
	options.push_back(3e6);
	options.push_back(4e6);
	options.push_back(5e6);
	options.push_back(6e6);
	options.push_back(7e6);
	options.push_back(8e6);
	options.push_back(9e6);
	options.push_back(10e6);
	return(options);
}
