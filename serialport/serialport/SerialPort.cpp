#include "pch.h"
#include <windows.h>
#include <string>
#include <vector>
#include <setupapi.h>
#include <devguid.h>
#include <regstr.h>
#include <iostream>

void DebugMessage(const char* message) {
    OutputDebugStringA(message);
}

void DebugMessageWithError(const char* message, DWORD error) {
    char buffer[256];
    sprintf_s(buffer, sizeof(buffer), "%s Error: %lu\n", message, error);
    OutputDebugStringA(buffer);
}

extern "C" __declspec(dllexport) HANDLE openSerialPort(const char* portName, int baudRate, int byteSize, int parity, int stopBits) {
    DebugMessage("Opening serial port...\n");

    std::string fullPortName = "\\\\.\\" + std::string(portName);
    int wchars_num = MultiByteToWideChar(CP_ACP, 0, fullPortName.c_str(), -1, NULL, 0);
    wchar_t* wstr = new wchar_t[wchars_num];
    MultiByteToWideChar(CP_ACP, 0, fullPortName.c_str(), -1, wstr, wchars_num);

    HANDLE hSerial = CreateFileW(wstr, GENERIC_READ | GENERIC_WRITE, 0, 0, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
    delete[] wstr;

    if (hSerial == INVALID_HANDLE_VALUE) {
        DWORD error = GetLastError();
        DebugMessageWithError("Failed to open serial port.", error);
        return nullptr;
    }

    DCB dcbSerialParams = { 0 };
    dcbSerialParams.DCBlength = sizeof(dcbSerialParams);

    if (!GetCommState(hSerial, &dcbSerialParams)) {
        DebugMessage("Failed to get COM state.\n");
        CloseHandle(hSerial);
        return nullptr;
    }

    dcbSerialParams.BaudRate = baudRate;
    dcbSerialParams.ByteSize = byteSize;
    dcbSerialParams.Parity = parity;
    dcbSerialParams.StopBits = stopBits;

    if (!SetCommState(hSerial, &dcbSerialParams)) {
        DebugMessage("Failed to set COM state.\n");
        CloseHandle(hSerial);
        return nullptr;
    }

    DebugMessage("Serial port opened successfully.\n");
    return hSerial;
}

extern "C" __declspec(dllexport) void closeSerialPort(HANDLE hSerial) {
    CloseHandle(hSerial);
    DebugMessage("Closed serial port.\n");
}

extern "C" __declspec(dllexport) int writeSerialPort(HANDLE hSerial, const char* data, int length) {
    DWORD bytesWritten;
    if (!WriteFile(hSerial, data, length, &bytesWritten, NULL)) {
        DebugMessage("Failed to write to serial port.\n");
        return -1;
    }
    DebugMessage("Data written to serial port.\n");
    return bytesWritten;
}

extern "C" __declspec(dllexport) int readSerialPort(HANDLE hSerial, char* buffer, int bufferSize) {
    DWORD bytesRead;
    if (!ReadFile(hSerial, buffer, bufferSize, &bytesRead, NULL)) {
        DebugMessage("Failed to read from serial port.\n");
        return -1;
    }
    buffer[bytesRead] = '\0'; // Null-terminate the string
    DebugMessage("Data read from serial port.\n");
    return bytesRead;
}

extern "C" __declspec(dllexport) int getSerialPorts(char* buffer, int bufferSize) {
    HDEVINFO hDevInfo;
    SP_DEVINFO_DATA DeviceInfoData;
    DWORD i;
    std::vector<std::string> ports;

    hDevInfo = SetupDiGetClassDevsA(&GUID_DEVCLASS_PORTS, 0, 0, DIGCF_PRESENT);
    if (hDevInfo == INVALID_HANDLE_VALUE) {
        DebugMessage("Failed to get device info set.\n");
        return 0;
    }

    DeviceInfoData.cbSize = sizeof(SP_DEVINFO_DATA);
    for (i = 0; SetupDiEnumDeviceInfo(hDevInfo, i, &DeviceInfoData); i++) {
        char instanceId[256];
        SetupDiGetDeviceInstanceIdA(hDevInfo, &DeviceInfoData, instanceId, sizeof(instanceId), 0);

        HKEY hDeviceRegistryKey = SetupDiOpenDevRegKey(hDevInfo, &DeviceInfoData, DICS_FLAG_GLOBAL, 0, DIREG_DEV, KEY_READ);
        if (hDeviceRegistryKey == INVALID_HANDLE_VALUE) {
            continue;
        }

        char portName[256];
        DWORD portNameSize = sizeof(portName);
        if (RegQueryValueExA(hDeviceRegistryKey, "PortName", NULL, NULL, (LPBYTE)portName, &portNameSize) == ERROR_SUCCESS) {
            ports.push_back(portName);
        }

        RegCloseKey(hDeviceRegistryKey);
    }

    SetupDiDestroyDeviceInfoList(hDevInfo);

    std::string combinedPorts;
    for (const auto& port : ports) {
        combinedPorts += port + ",";
    }
    if (!combinedPorts.empty()) {
        combinedPorts.pop_back();
    }

    strncpy_s(buffer, bufferSize, combinedPorts.c_str(), bufferSize - 1);

    DebugMessage("COM ports enumerated successfully.\n");
    return ports.size();
}
