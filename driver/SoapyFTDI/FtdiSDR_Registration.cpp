#include "SoapyFtdiSDR.hpp"
#include <SoapySDR/Registry.hpp>



static std::vector<SoapySDR::Kwargs> find_FtdiSDR(const SoapySDR::Kwargs &args) {
	std::vector<SoapySDR::Kwargs> results;
	SoapySDR::Kwargs soapyInfo;

	soapyInfo["device"] = "FtdiSDR";
	soapyInfo["label"] = "Nebi's SDR";
	results.push_back(soapyInfo);
	return results;
}

static SoapySDR::Device *make_FtdiSDR(const SoapySDR::Kwargs &args)
{
	return new SoapyFtdiSDR(args);
}

static SoapySDR::Registry register_ftdisdr("ftdisdr", &find_FtdiSDR, &make_FtdiSDR, SOAPY_SDR_ABI_VERSION);
