import 'dart:io';

// Conditional import based on the platform

import 'serial_port_manager_windows.dart';
//    if (dart.library.io) 'serial_port_manager_linux.dart';

abstract class SerialPortManager {
  List<String> fetchPorts();
  Future<void> openPort(String portName, int baudRate, int byteSize, int parity, int stopBits, Function(String) onDataReceived);
  void sendData(String data);
  Future<void> closePort();
}

SerialPortManager getSerialPortManager() {
  if (Platform.isWindows) {
    return SerialPortManagerWindows();
  }  else {
    throw UnsupportedError('Unsupported platform');
  }
}
