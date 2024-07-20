import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'package:ffi/ffi.dart';

import 'serial_port_manager.dart';

typedef GetSerialPortsC = Int32 Function(Pointer<Utf8> buffer, Int32 bufferSize);
typedef GetSerialPortsDart = int Function(Pointer<Utf8> buffer, int bufferSize);

typedef OpenSerialPortC = Pointer<Void> Function(Pointer<Utf8> portName, Int32 baudRate, Int32 byteSize, Int32 parity, Int32 stopBits);
typedef OpenSerialPortDart = Pointer<Void> Function(Pointer<Utf8> portName, int baudRate, int byteSize, int parity, int stopBits);

typedef CloseSerialPortC = Void Function(Pointer<Void> hSerial);
typedef CloseSerialPortDart = void Function(Pointer<Void> hSerial);

typedef WriteSerialPortC = Int32 Function(Pointer<Void> hSerial, Pointer<Utf8> data, Int32 length);
typedef WriteSerialPortDart = int Function(Pointer<Void> hSerial, Pointer<Utf8> data, int length);

typedef ReadSerialPortC = Int32 Function(Pointer<Void> hSerial, Pointer<Utf8> buffer, Int32 bufferSize);
typedef ReadSerialPortDart = int Function(Pointer<Void> hSerial, Pointer<Utf8> buffer, int bufferSize);

class SerialPortManagerWindows implements SerialPortManager {
  late DynamicLibrary _serialPortLib;
  late GetSerialPortsDart _getSerialPorts;
  late OpenSerialPortDart _openSerialPort;
  late CloseSerialPortDart _closeSerialPort;
  late WriteSerialPortDart _writeSerialPort;
  late ReadSerialPortDart _readSerialPort;

  Pointer<Void>? _hSerial;
  ReceivePort? _receivePort;
  Isolate? _isolate;

  SerialPortManagerWindows() {
    _serialPortLib = DynamicLibrary.open('windows/SerialPort.dll');
    _getSerialPorts = _serialPortLib
        .lookup<NativeFunction<GetSerialPortsC>>('getSerialPorts')
        .asFunction();
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
    final buffer = calloc<Uint8>(1024);
    final numPorts = _getSerialPorts(buffer.cast(), 1024);
    final portsString = buffer.cast<Utf8>().toDartString();
    calloc.free(buffer);

    return portsString.split(',').where((port) => port.isNotEmpty).toList();
  }

  @override
  Future<void> openPort(String portName, int baudRate, int byteSize, int parity, int stopBits, Function(String) onDataReceived) async {
    await closePort(); // Ensure any previously opened port is closed

    final portNamePtr = portName.toNativeUtf8();
    _hSerial = _openSerialPort(portNamePtr, baudRate, byteSize, parity, stopBits);
    malloc.free(portNamePtr);

    if (_hSerial != null) {
      _receivePort = ReceivePort();
      _isolate = await Isolate.spawn(_startReading, SerialPortTask(_hSerial!, _receivePort!.sendPort));
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
    final DynamicLibrary serialPortLib = DynamicLibrary.open('SerialPort.dll');
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
      final bytesRead = readSerialPort(task.hSerial, buffer.cast(), 1024);
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
    if (_hSerial != null) {
      final dataPtr = data.toNativeUtf8();
      _writeSerialPort(_hSerial!, dataPtr, dataPtr.length);
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
    if (_hSerial != null) {
      _closeSerialPort(_hSerial!);
      _hSerial = null;
    }
    _closeReceivePort();
  }
}

class SerialPortTask {
  final Pointer<Void> hSerial;
  final SendPort sendPort;

  SerialPortTask(this.hSerial, this.sendPort);
}

class ClosePortMessage {}
