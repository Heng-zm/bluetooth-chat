import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io'; 
import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

// Project-specific imports - ensure these paths match your folder structure
import 'encryption_service.dart';
import '../models/message_model.dart';
import '../models/device_model.dart';

enum BluetoothConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
  error,
}

class BluetoothService extends ChangeNotifier {
  final EncryptionService _encryption;
  BluetoothConnection? _connection;
  StreamSubscription? _inputSubscription;
  StreamSubscription? _discoverySubscription;
  
  String _buffer = '';
  BluetoothConnectionState _state = BluetoothConnectionState.disconnected;
  
  List<BTDevice> _pairedDevices = [];
  List<BTDevice> _discoveredDevices = [];
  List<Message> _messages = [];
  
  String? _connectedDeviceName;
  String? _errorMessage;
  bool _isDiscovering = false;

  BluetoothService({EncryptionService? encryption})
      : _encryption = encryption ?? EncryptionService();

  // --- Getters ---
  BluetoothConnectionState get state => _state;
  List<BTDevice> get pairedDevices => _pairedDevices;
  List<BTDevice> get discoveredDevices => _discoveredDevices;
  List<Message> get messages => _messages;
  String? get connectedDeviceName => _connectedDeviceName;
  String? get errorMessage => _errorMessage;
  bool get isDiscovering => _isDiscovering;
  bool get isConnected => _state == BluetoothConnectionState.connected;
  EncryptionService get encryptionService => _encryption;

  /// Initialize Bluetooth and check permissions
  Future<void> initialize() async {
    if (!Platform.isAndroid) {
      debugPrint("Bluetooth Service: Non-Android platform detected. Native calls disabled.");
      return;
    }

    try {
      final isEnabled = await FlutterBluetoothSerial.instance.isEnabled ?? false;
      if (!isEnabled) {
        await FlutterBluetoothSerial.instance.requestEnable();
      }
      await loadPairedDevices();
    } catch (e) {
      _setError('Failed to initialize Bluetooth: $e');
    }
  }

  /// Load already paired (bonded) devices from the OS
  Future<void> loadPairedDevices() async {
    if (!Platform.isAndroid) return;

    try {
      final bonded = await FlutterBluetoothSerial.instance.getBondedDevices();
      _pairedDevices = bonded.map((d) => BTDevice(
        name: d.name ?? 'Unknown Device',
        address: d.address,
        type: _deviceTypeFromBT(d.type),
        isPaired: true,
      )).toList();
      notifyListeners();
    } catch (e) {
      _setError('Could not load paired devices: $e');
    }
  }

  /// Scan for new nearby devices
  Future<void> startDiscovery() async {
    if (!Platform.isAndroid || _isDiscovering) return;

    _discoveredDevices.clear();
    _isDiscovering = true;
    _setState(BluetoothConnectionState.scanning);

    _discoverySubscription = FlutterBluetoothSerial.instance.startDiscovery().listen(
      (result) {
        final device = BTDevice(
          name: result.device.name ?? 'Unknown',
          address: result.device.address,
          type: _deviceTypeFromBT(result.device.type),
          rssi: result.rssi,
          isPaired: result.device.isBonded,
        );

        final idx = _discoveredDevices.indexWhere((d) => d.address == device.address);
        if (idx >= 0) {
          _discoveredDevices[idx] = device;
        } else {
          _discoveredDevices.add(device);
        }
        notifyListeners();
      },
      onDone: () {
        _isDiscovering = false;
        if (_state == BluetoothConnectionState.scanning) {
          _setState(BluetoothConnectionState.disconnected);
        }
      },
      onError: (e) {
        _isDiscovering = false;
        _setError('Discovery error: $e');
      },
    );
  }

  /// Stop the current discovery process
  Future<void> stopDiscovery() async {
    if (!Platform.isAndroid) return;
    await _discoverySubscription?.cancel();
    await FlutterBluetoothSerial.instance.cancelDiscovery();
    _isDiscovering = false;
    notifyListeners();
  }

  /// Connect to a specific device via MAC address
  Future<void> connectToDevice(BTDevice device) async {
    if (!Platform.isAndroid) {
      _setError("Bluetooth Serial is only supported on Android.");
      return;
    }
    
    if (_state == BluetoothConnectionState.connecting) return;

    _setState(BluetoothConnectionState.connecting);
    _messages.clear();

    try {
      _connection = await BluetoothConnection.toAddress(device.address);
      _connectedDeviceName = device.name;
      _setState(BluetoothConnectionState.connected);

      _inputSubscription = _connection!.input!.listen(
        _onDataReceived,
        onDone: () => disconnect(),
        onError: (e) => _setError('Connection lost: $e'),
        cancelOnError: false,
      );
    } catch (e) {
      _setState(BluetoothConnectionState.disconnected);
      _setError('Could not connect to ${device.name}: $e');
    }
  }

  /// Disconnect and clean up streams
  Future<void> disconnect() async {
    await _inputSubscription?.cancel();
    await _connection?.close();
    _connection = null;
    _connectedDeviceName = null;
    _setState(BluetoothConnectionState.disconnected);
  }

  /// Encrypt and send a message packet
  Future<void> sendMessage(String text) async {
    if (!isConnected || text.trim().isEmpty) return;

    try {
      final encrypted = _encryption.encrypt(text.trim());
      // Packet Framing: Encode as JSON and add a newline character
      final packet = jsonEncode({'t': encrypted, 'v': '1'}) + '\n';
      
      _connection!.output.add(Uint8List.fromList(utf8.encode(packet)));
      await _connection!.output.allSent;

      final message = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text.trim(),
        encryptedText: encrypted,
        isMine: true,
        timestamp: DateTime.now(),
      );
      
      _messages.add(message);
      notifyListeners();
    } catch (e) {
      _setError('Failed to send message: $e');
    }
  }

  /// Handles stream fragmentation using a newline-terminated buffer
  void _onDataReceived(Uint8List data) {
    _buffer += utf8.decode(data, allowMalformed: true);

    while (_buffer.contains('\n')) {
      final newlineIdx = _buffer.indexOf('\n');
      final line = _buffer.substring(0, newlineIdx).trim();
      _buffer = _buffer.substring(newlineIdx + 1);

      if (line.isEmpty) continue;

      try {
        final json = jsonDecode(line) as Map<String, dynamic>;
        final encryptedText = json['t'] as String? ?? '';
        final decryptedText = _encryption.decrypt(encryptedText);

        _messages.add(Message(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: decryptedText,
          encryptedText: encryptedText,
          isMine: false,
          timestamp: DateTime.now(),
        ));
      } catch (e) {
        _messages.add(Message(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: '[Decryption Error or Malformed Packet]',
          encryptedText: line,
          isMine: false,
          timestamp: DateTime.now(),
          isDecryptionError: true,
        ));
      }
      notifyListeners();
    }
  }

  void updatePassphrase(String passphrase) {
    _encryption.updatePassphrase(passphrase);
    notifyListeners();
  }

  void _setState(BluetoothConnectionState newState) {
    _state = newState;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    _state = BluetoothConnectionState.error;
    notifyListeners();
  }

  String _deviceTypeFromBT(BluetoothDeviceType type) {
    switch (type) {
      case BluetoothDeviceType.classic: return 'Classic';
      case BluetoothDeviceType.le:      return 'BLE';
      case BluetoothDeviceType.dual:    return 'Dual';
      default:                          return 'Unknown';
    }
  }

  void clearError() {
    _errorMessage = null;
    if (_state == BluetoothConnectionState.error) {
      _state = BluetoothConnectionState.disconnected;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _inputSubscription?.cancel();
    _discoverySubscription?.cancel();
    _connection?.dispose();
    super.dispose();
  }
}
