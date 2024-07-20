import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'package:ffi/ffi.dart';

import 'serial_port_manager.dart';

typedef OpenSerialPortC = Int32 Function(Pointer<Utf8> portName, Int32 baudRate, Int32 byteSize, Int32 parity, Int32 stopBits);
typedef OpenSerialPortDart = int Function(Pointer<Utf8> portName, int baudRate, int byteSize, int parity, int stopBits);

typedef CloseSerialPortC = Void Function(Int32 fd);
typedef CloseSerialPortDart = void Function(int fd);

typedef WriteSerialPortC = Int32 Function(Int32 fd, Pointer<Utf8> data, Int32 length);
typedef WriteSerialPortDart = int Function(int fd, Pointer<Utf8> data, int length);

typedef ReadSerialPortC = Int32 Function(Int32 fd, Pointer<Utf8> buffer, Int32 bufferSize);
typedef ReadSerialPortDart = int Function(int fd, Pointer<Utf8> buffer, int bufferSize);

class SerialPortManagerLinux implements SerialPortManager {
  late DynamicLibrary _serialPortLib;
  late OpenSerialPortDart _openSerialPort;
  late CloseSerialPortDart _closeSerialPort;
  late WriteSerialPortDart _writeSerialPort;
  late ReadSerialPortDart _readSerialPort;

  int? _fd;
  ReceivePort? _receivePort;
  Isolate? _isolate;

  SerialPortManagerLinux() {
    _serialPortLib = DynamicLibrary.open('libserialport.so');
    _openSerialPort = _serialPortLib
        .lookup<NativeFunction<OpenSerialPortC>>('openSerialPort')
        .asFunction();
    _closeSerialPort = _serialPortLib
        .lookup<NativeFunction<CloseSerialPortC>>('closeSerialPort')
        .asFunction();
    _writeSerialPort = _serialPortLib
        .lookup<NativeFunction<WriteSerialPortC>>('writeSerialPort')
        .asFunction();
    _readSerialPort = _serialPortLib
        .lookup<NativeFunction<ReadSerialPortC>>('readSerialPort')
        .asFunction();
  }

  @override
  List<String> fetchPorts() {
    final ports = <String>[];
    final devDir = Directory('/dev');
    if (devDir.existsSync()) {
      final devices = devDir.listSync();
      for (var device in devices) {
        final deviceName = device.path.split('/').last;
        if (deviceName.startsWith('ttyS') || deviceName.startsWith('ttyUSB') || deviceName.startsWith('ttyACM')) {
          ports.add(device.path);
        }
      }
    }
    return ports;
  }

  @override
  Future<void> openPort(String portName, int baudRate, int byteSize, int parity, int stopBits, Function(String) onDataReceived) async {
    await closePort(); // Ensure any previously opened port is closed

    final portNamePtr = portName.toNativeUtf8();
    _fd = _openSerialPort(portNamePtr, baudRate, byteSize, parity, stopBits);
    malloc.free(portNamePtr);

    if (_fd != -1) {
      _receivePort = ReceivePort();
      _isolate = await Isolate.spawn(_startReading, SerialPortTask(_fd!, _receivePort!.sendPort));
      _receivePort!.listen((data) {
        if (data is String) {
          onDataReceived(data);
        } else if (data is ClosePortMessage) {
          _closeReceivePort();
        }
      });
    }
  }

  static void _startReading(SerialPortTask task) async {
    final DynamicLibrary serialPortLib = DynamicLibrary.open('libserialport.so');
    final readSerialPort = serialPortLib
        .lookup<NativeFunction<ReadSerialPortC>>('readSerialPort')
        .asFunction<ReadSerialPortDart>();

    final buffer = calloc<Uint8>(1024);
    final receivePort = ReceivePort();
    task.sendPort.send(receivePort.sendPort);

    bool running = true;

    receivePort.listen((message) {
      if (message is ClosePortMessage) {
        running = false;
        receivePort.close();
      }
    });

    while (running) {
      final bytesRead = readSerialPort(task.fd, buffer.cast(), 1024);
      if (bytesRead > 0) {
        final receivedData = buffer.cast<Utf8>().toDartString();
        task.sendPort.send(receivedData);
      }
      await Future.delayed(Duration(milliseconds: 100)); // Reduced delay for faster reading
    }
    calloc.free(buffer);
  }

  @override
  void sendData(String data) {
    if (_fd != null) {
      final dataPtr = data.toNativeUtf8();
      _writeSerialPort(_fd!, dataPtr, dataPtr.length);
      malloc.free(dataPtr);
    }
  }

  @override
  Future<void> closePort() async {
    if (_isolate != null) {
      _receivePort?.sendPort.send(ClosePortMessage());
      _isolate?.kill(priority: Isolate.immediate);
      _isolate = null;
    }
    _closePortInternal();
  }

  void _closeReceivePort() {
    _receivePort?.close();
    _receivePort = null;
  }

  void _closePortInternal() {
    if (_fd != null) {
      _closeSerialPort(_fd!);
      _fd = null;
    }
    _closeReceivePort();
  }
}

class SerialPortTask {
  final int fd;
  final SendPort sendPort;

  SerialPortTask(this.fd, this.sendPort);
}

class ClosePortMessage {}
