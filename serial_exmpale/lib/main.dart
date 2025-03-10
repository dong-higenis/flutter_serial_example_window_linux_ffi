import 'package:flutter/material.dart';
import 'serial_port_manager.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter COM Port Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final SerialPortManager _serialPortManager = getSerialPortManager();
  List<String> _ports = [];
  String? _selectedPort;
  int _baudRate = 115200;
  int _byteSize = 8;
  int _parity = 0;
  int _stopBits = 1;
  String _receivedData = '';
  bool _isPortOpen = false;

  @override
  void initState() {
    super.initState();
    _fetchPorts();
  }

  void _fetchPorts() {
    setState(() {
      _ports = _serialPortManager.fetchPorts();
      if (_ports.isNotEmpty) {
        _selectedPort = _ports.first;
      }
    });
  }

  Future<void> _togglePort() async {
    if (_isPortOpen) {
      await _closePort();
    } else {
      await _openPort();
    }
  }

  Future<void> _openPort() async {
    if (_selectedPort != null) {
      await _serialPortManager.openPort(
        _selectedPort!,
        _baudRate,
        _byteSize,
        _parity,
        _stopBits,
        (data) {
          setState(() {
            _receivedData = data;
          });
        },
      );
      setState(() {
        _isPortOpen = true;
      });
    }
  }

  Future<void> _closePort() async {
    await _serialPortManager.closePort();
    setState(() {
      _isPortOpen = false;
      _receivedData = '';
    });
  }

  void _sendData() {
    _serialPortManager.sendData('Hello, COM Port!');
  }

  @override
  void dispose() {
    _serialPortManager.closePort();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Flutter COM Port Example'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            DropdownButton<String>(
              value: _selectedPort,
              onChanged: (String? newValue) {
                setState(() {
                  _selectedPort = newValue;
                });
                if (_isPortOpen) {
                  _closePort();
                }
              },
              items: _ports.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
            TextField(
              decoration: InputDecoration(labelText: 'Baud Rate'),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                _baudRate = int.tryParse(value) ?? 115200;
              },
            ),
            TextField(
              decoration: InputDecoration(labelText: 'Byte Size'),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                _byteSize = int.tryParse(value) ?? 8;
              },
            ),
            TextField(
              decoration: InputDecoration(labelText: 'Parity (0=None, 1=Odd, 2=Even)'),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                _parity = int.tryParse(value) ?? 0;
              },
            ),
            TextField(
              decoration: InputDecoration(labelText: 'Stop Bits (0=1, 1=1.5, 2=2)'),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                _stopBits = int.tryParse(value) ?? 1;
              },
            ),
            ElevatedButton(
              onPressed: _togglePort,
              child: Text(_isPortOpen ? 'Close Port' : 'Open Port'),
            ),
            if (_isPortOpen)
              ElevatedButton(
                onPressed: _sendData,
                child: Text('Send Data to COM Port'),
              ),
            Text('Received Data: $_receivedData'),
          ],
        ),
      ),
    );
  }
}
