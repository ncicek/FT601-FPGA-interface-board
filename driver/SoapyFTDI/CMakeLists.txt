########################################################################
# Project setup -- only needed if device support is a stand-alone build
# We recommend that the support module be built in-tree with the driver.
########################################################################
cmake_minimum_required(VERSION 2.6)
project(SoapyFtdiSDR CXX)
enable_testing()

#select the release build type by default to get optimization flags
if(NOT CMAKE_BUILD_TYPE)
   set(CMAKE_BUILD_TYPE "Release")
   message(STATUS "Build type not specified: defaulting to release.")
endif(NOT CMAKE_BUILD_TYPE)
set(CMAKE_BUILD_TYPE ${CMAKE_BUILD_TYPE} CACHE STRING "")

########################################################################
# Header and library resources needed to communicate with the device.
# These may be found within the build tree or in an external project.
########################################################################
set(FTDI_INCLUDE_DIRS "")
set(FTDI_LIBRARIES "ftd3xx")

########################################################################
# build the module
########################################################################
find_package(SoapySDR CONFIG)

if (NOT SoapySDR_FOUND)
    message(WARNING "SoapySDR development files not found - skipping support")
    return()
endif ()

include_directories(${FTDI_INCLUDE_DIRS})
SOAPY_SDR_MODULE_UTIL(
    TARGET Ftdi
    SOURCES SoapyFtdiSDR.hpp
            FtdiSDR_Registration.cpp
            FtdiSDR_Settings.cpp
            FtdiSDR_Streaming.cpp
    LIBRARIES ${FTDI_LIBRARIES}
)
