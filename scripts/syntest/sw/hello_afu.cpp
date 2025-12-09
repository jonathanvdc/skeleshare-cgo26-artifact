//
// Copyright (c) 2017, Intel Corporation
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// Redistributions of source code must retain the above copyright notice, this
// list of conditions and the following disclaimer.
//
// Redistributions in binary form must reproduce the above copyright notice,
// this list of conditions and the following disclaimer in the documentation
// and/or other materials provided with the distribution.
//
// Neither the name of the Intel Corporation nor the names of its contributors
// may be used to endorse or promote products derived from this software
// without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.

#include <stdint.h>
#include <stdlib.h>
#include <unistd.h>
#include <time.h>
//#include <hugetlbfs.h>
#include <assert.h>

#include <iostream>
#include <fstream>
#include <iomanip>
#include <string>
#include <limits.h>
#include <string.h>

using namespace std;

#include "opae_svc_wrapper.h"

// State from the AFU's JSON file, extracted using OPAE's afu_json_mgr script
#include "afu_json_info.h"

//#define SW_TEST 1


#define FINISHED_REG        0x80
#define CYCLES_REG          0x88
#define OFFSET_REG          0x0
#define OFFSET_VALID_REG    0x8


void array_reset(volatile char* buf, int len);
void array_change_endian(volatile char* a, int len);
void array_print(volatile char* buf, int len);
void array_print(uint64_t* buf, int len);
void array_get(volatile char* buf, int cacheLine, uint64_t* values, int valuesLen, int valueBitWidth);
void array_put(volatile char* buf, int cacheLine, uint64_t* values, int valuesLen, int valueBitWidth);
int array_load_file(volatile char* buf, string filename);
bool check_memory(volatile char* buf, int len);

int main(void)
{
	int i;
	uint64_t data;
	fpga_result res = FPGA_OK;

	// Find and connect to the accelerator
#ifndef SW_TEST
	OPAE_SVC_WRAPPER* fpga = new OPAE_SVC_WRAPPER(AFU_ACCEL_UUID);
	assert(fpga->isOk());
#endif

	// Allocate a single page memory buffer
	volatile char* buf;
	uint64_t page_len = 1024*1024*1000; //100MB for now //gethugepagesize(); //getpagesize();
	//cout << getpagesize() << " " << getpagesizes(NULL, 0) << endl;
#ifndef SW_TEST
	uint64_t buf_pa;
	cout << "allocating memory page with " << page_len << " bytes" << endl;
	cout << "one word (cache line) in this buffer has " << CL(1) << " bytes" << endl;
	buf = (volatile char*)fpga->allocBuffer(page_len, &buf_pa);
#else
    buf = (volatile char*)malloc(page_len * sizeof(char));
#endif
	assert(buf);
    // array_reset(buf, page_len);
    //check_memory(buf, page_len); // warning: changes memory! comparison may fail!

    array_load_file(buf, "mem_initial.dat");
    array_change_endian(buf, page_len);

    //uint64_t values1[] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20};
    //uint64_t values2[] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20};
    //array_put(buf, 1, values1, 4, 8);
    //array_put(buf, 2, values2, 4, 8);

#ifndef SW_TEST
	// Tell the accelerator the address of the buffer using cache line addresses
	res = fpga->mmioWrite64(OFFSET_REG, buf_pa / CL(1));
	assert(res == FPGA_OK);

	data = 1;
	res = fpga->mmioWrite64(OFFSET_VALID_REG, data);
	assert(res == FPGA_OK);

	//res = fpga->mmioWrite64(0x10, data);
	//assert(res == FPGA_OK);

    clock_t clocktime;
    clocktime = clock();

	// Spin, waiting for finished
    do {
		// save power here
		usleep(10000000); // 10s
        cout << "waiting for fpga to finish ..." << endl;
	    uint64_t writereq = fpga->mmioRead64(0xC8);
        cout << writereq << " writes requested." << endl;
	} while (fpga->mmioRead64(FINISHED_REG) != 1);

    clocktime = clock() - clocktime;
    double timetaken = ((double)clocktime)/CLOCKS_PER_SEC;

	uint64_t cycles = fpga->mmioRead64(CYCLES_REG);
	uint64_t readreq = fpga->mmioRead64(0xC0);
	uint64_t readpending = fpga->mmioRead64(0xD0);
	uint64_t writereq = fpga->mmioRead64(0xC8);
	uint64_t writepending = fpga->mmioRead64(0xD8);
	uint64_t readaf = fpga->mmioRead64(0xE0);
	uint64_t writeaf = fpga->mmioRead64(0xE8);

#endif

    char* final_mem = (char*)malloc(page_len * sizeof(char));
	assert(final_mem);
    array_reset(final_mem, page_len);
    int data_len = array_load_file(final_mem, "mem_final.dat");
    array_change_endian(final_mem, page_len);

	//array_print(buf, data_len);//1000*CL(1));
    //cout << "##############" << endl;
	//array_print(final_mem, data_len);//1000*CL(1));

    bool correct = memcmp((char*)buf, final_mem, data_len) == 0;
    if (correct)
        cout << "result is correct!" << endl;
    else
        cout << "result is NOT correct!" << endl;

    //uint64_t result[4];
    //array_get(buf, 0, result, 4, 64);
    //array_print(result, 4);

#ifndef SW_TEST
	cout << endl << (fpga->hwIsSimulated() ? "finished simulation" : "finished using FPGA");
    cout << " after " << timetaken << " seconds." << endl;
    cout << "accelerator required " << cycles << " cycles, " << readreq << " read requests (of which " << readpending << " pending), " << writereq << " write requests (of which " << writepending << " pending) for this task. Read request buffer was " << readaf << " times almost full. Write request buffer was " << writeaf << " times almost full." << endl;
	delete fpga;
#endif

	return 0;
}

void array_reset(volatile char* buf, int len)
{
    int i;
	for (i = 0; i < len; i++)
		buf[i] = 0;
}

void array_change_endian(volatile char* buf, int len)
{
	int i, j;
	int wordlength = CL(1);
	for (i = 0; i < len; i += wordlength)
	{
		for (j = 0; j < wordlength/2; j++)
		{
			char tmp = buf[i + j];
			buf[i + j] = buf[i + wordlength - 1 - j];
			buf[i + wordlength - 1 - j] = tmp;
		}
	}
}

void array_print(volatile char* buf, int len)
{
	int i;
	for (i = 0; i < len; i++)
	{
		cout << setfill('0') << setw(2) << hex << (0xff & (unsigned int)buf[i]);
		if ((i + 1) % CL(1) == 0)
			cout << endl;
	}
    cout << dec;
}

void array_print(uint64_t* buf, int len)
{
    int i;
    for (i = 0; i < len-1; i++)
        cout << ((unsigned int)buf[i]) << ", ";
    cout << buf[len-1] << endl;
}

void array_get(volatile char* buf, int cacheLine, uint64_t* values, int valuesLen, int valueBitWidth)
{
    int valueIdx, consumedBits, discardBits, useBits, bitPosInCL = 0;
    char byte;
    uint64_t value;
    for (valueIdx = 0; valueIdx < valuesLen; valueIdx++)
    {
        values[valueIdx] = 0;
        consumedBits = 0;
        while(consumedBits < valueBitWidth)
        {
            discardBits = (bitPosInCL + consumedBits) % CHAR_BIT;
            useBits = CHAR_BIT - discardBits;
            // get current byte and shift right to discard 'discardBits' lowest bits
            byte = buf[CL(cacheLine) + (bitPosInCL + consumedBits) / CHAR_BIT];
            byte >>= discardBits;
            if (useBits > valueBitWidth - consumedBits)
            {
                useBits = valueBitWidth - consumedBits;
                // use only the first 'useBits' bits, set others to 0
                byte &= (1<<useBits)-1;
            }
            // sanitise byte with 0xff (otherwise negative values can mess things up)
            value = 0xff & byte; // if we kept working with a byte only, we would have overflow errors
            values[valueIdx] |= value << consumedBits;
            consumedBits += useBits;
        }
        bitPosInCL += valueBitWidth;
        if (bitPosInCL + valueBitWidth > CL(1) * CHAR_BIT)
        {
            cacheLine += 1;
            bitPosInCL = 0;
        }
    }
}

// puts values into the array in a little endian style (bitwise) ignoring byte boundaries!
void array_put(volatile char* buf, int cacheLine, uint64_t* values, int valuesLen, int valueBitWidth)
{
    int valueIdx, discardBits, useBits, currentPos, bitPosInCL = 0;
    char byte;
    uint64_t value;
    for (valueIdx = 0; valueIdx < valuesLen; valueIdx++)
    {
        currentPos = bitPosInCL;
        value = values[valueIdx];
        while (value > 0)
        {
            discardBits = (currentPos % CHAR_BIT);
            useBits = CHAR_BIT - discardBits;
            // get lowest 'useBits' bits of value and shift them 'discardBits' to the left
            byte = (value & ((1<<useBits)-1)) << discardBits;
            buf[CL(cacheLine) + (currentPos / CHAR_BIT)] |= byte;
            value >>= useBits;
            currentPos += useBits;
        }

        bitPosInCL += valueBitWidth;
        if (bitPosInCL + valueBitWidth > CL(1) * CHAR_BIT)
        {
            cacheLine += 1;
            bitPosInCL = 0;
        }
    }
}

int array_load_file(volatile char* buf, string filename)
{
    fstream fin(filename, fstream::in);
    if (!fin)
        cout << "memory image file '" << filename << "' not found!" << endl;
    assert(fin);

    char c = 0;
    char byte = 0;

    int pos = 0;
    int receivedbits = 0;
    while(fin >> c)
    {
        if (c == '1') {
            byte <<= 1;
            byte++;
        } else if (c == '0') {
            byte <<= 1;
        } else {
            continue;
        }

        receivedbits++;
        if (receivedbits >= CHAR_BIT)
        {
            buf[pos] = byte;
            pos++;
            receivedbits = 0;
        }
    }
    return pos;
}

bool check_memory(volatile char* buf, int len)
{
    char* check_buf = (char*)malloc(len * sizeof(char));
    memset(check_buf, 9, len);
    memcpy((void*)buf, check_buf, len);

    bool correct = memcmp((char*)buf, (char*)check_buf, len) == 0;
    if (!correct)
        cout << "memory is not working correctly!" << endl;
    else
        cout << "memory checked successfully!" << endl;

    return correct;
}
