#pragma once

#ifdef SERIALPORT_EXPORTS
#define SERIALPORT_API __declspec(dllexport)
#else
#define SERIALPORT_API __declspec(dllimport)
#endif

#include <windows.h>

extern "C" SERIALPORT_API HANDLE openSerialPort(const char* portName, int baudRate, int byteSize, int parity, int stopBits);
extern "C" SERIALPORT_API void closeSerialPort(HANDLE hSerial);
extern "C" SERIALPORT_API int writeSerialPort(HANDLE hSerial, const char* data, int length);
extern "C" SERIALPORT_API int readSerialPort(HANDLE hSerial, char* buffer, int bufferSize);
extern "C" SERIALPORT_API int getSerialPorts(char* buffer, int bufferSize);
