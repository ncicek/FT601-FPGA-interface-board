#include "ftd3xx.h"
#include <stdio.h>
#include <sys/time.h>

struct timeval ts1, ts2;


FT_HANDLE connect(void) {
    unsigned int num_devices;
    FT_DEVICE_DESCRIPTOR descriptor;
    FT_HANDLE handle = NULL;
    FT_CreateDeviceInfoList(&num_devices);
    if (num_devices == 0) {
        printf("Could not find ftdi device\n");
        return 0;
    }
	FT_Create(0, FT_OPEN_BY_INDEX, &handle);
    FT_GetDeviceDescriptor(handle, &descriptor);
    if (descriptor.bcdUSB >= 0x300) {
        printf("USB3.1\n");
    } else {
        printf("USB2.0\n");
    }
    return handle;
}

int main(void)
{

    #define BUFFER_SIZE (32*1024)
    uint32_t buffer_size = BUFFER_SIZE;
    uint8_t buffer[BUFFER_SIZE];

    FT_STATUS status;
    FT_HANDLE handle = connect();
    if (handle == 0) {
        return 0;
    }

    status = FT_SetStreamPipe(handle,FALSE,TRUE,0x82, buffer_size);
    printf("stream_pipe_status: %d\n", status);
    //return 0;

    uint32_t bytes_transfered;

    uint16_t mesasure_rate = 1;
    while(1) {
        mesasure_rate++;
        if (mesasure_rate == 0) {
            gettimeofday(&ts2,NULL);
            uint32_t elapsed = ((ts2.tv_sec - ts1.tv_sec) * 1000000) + (ts2.tv_usec - ts1.tv_usec);
            printf("data rate = %d MB/s\n", (1<<16)*buffer_size/elapsed);
            gettimeofday(&ts1,NULL);
        }

        FT_ReadPipeEx(handle, 0, buffer, buffer_size, &bytes_transfered, 2000);
        //printf("%d\n", status);   
        //printf("%d\n", bytes_transfered);

        /*if (bytes_transfered != buffer_size) {
            printf("LOL\n");
            break;
        }*/
        if (1) {
            uint32_t previous_dword;

            for (uint32_t i = 0; i < (buffer_size / 4); i++) {
                uint32_t dword = 0;

                for (uint8_t j = 0; j < 4; j++) {
                    uint32_t index = i*4 + j;
                    //printf("index %d, data %d\n", index, buffer[index]);
                    dword |= buffer[index] << (j * 8);
                }

                //printf("%u\n", dword);

                /*if (i != 0) {
                    if (dword != ((uint64_t)previous_dword << 1) % 0xffffffff) {
                        printf("error!\n");
                        printf("%u\n", dword);
                        printf("%u\n", previous_dword);

                        return 0;
                    }
                }*/
                previous_dword = dword;
            }
        }
    }

    FT_Close(handle);
	return 0;
}
