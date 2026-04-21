import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/bluetooth_service.dart';
import '../models/device_model.dart';
import '../theme/app_theme.dart';
import '../widgets/bt_signal_bars.dart';
import '../widgets/glow_container.dart';
import '../widgets/scan_animation.dart';
import 'chat_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
    ].request();

    if (mounted) {
      final service = context.read<BluetoothService>();
      await service.initialize();
      setState(() => _initialized = true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      appBar: _buildAppBar(context),
      body: _initialized ? _buildBody(context) : _buildLoading(),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppTheme.bgDeep,
      title: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.accentCyan,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentCyan.withOpacity(0.7),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Text('BT SECURECHAT'),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.security, color: AppTheme.accentCyan),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
          tooltip: 'Security Settings',
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                AppTheme.accentCyan.withOpacity(0.3),
                AppTheme.accentCyan.withOpacity(0.5),
                AppTheme.accentCyan.withOpacity(0.3),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ScanAnimation(size: 120),
          const SizedBox(height: 24),
          Text(
            'INITIALIZING BLUETOOTH',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.accentCyan,
                  letterSpacing: 2,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Consumer<BluetoothService>(
      builder: (context, service, _) {
        if (service.state == BluetoothConnectionState.connected) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const ChatScreen()),
            );
          });
        }

        return Column(
          children: [
            _buildStatusBanner(service),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildScanButton(service),
                    if (service.errorMessage != null) ...[
                      const SizedBox(height: 16),
                      _buildErrorBanner(service),
                    ],
                    const SizedBox(height: 24),
                    if (service.pairedDevices.isNotEmpty) ...[
                      _buildSectionHeader('PAIRED DEVICES', Icons.devices),
                      const SizedBox(height: 12),
                      ...service.pairedDevices
                          .map((d) => _buildDeviceTile(context, d, service)),
                      const SizedBox(height: 24),
                    ],
                    if (service.discoveredDevices.isNotEmpty) ...[
                      _buildSectionHeader(
                          'NEARBY DEVICES', Icons.bluetooth_searching),
                      const SizedBox(height: 12),
                      ...service.discoveredDevices
                          .map((d) => _buildDeviceTile(context, d, service)),
                    ],
                    if (service.isDiscovering) ...[
                      const SizedBox(height: 16),
                      _buildDiscoveringIndicator(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusBanner(BluetoothService service) {
    Color color;
    String text;
    IconData icon;

    switch (service.state) {
      case BluetoothConnectionState.connecting:
        color = AppTheme.warning;
        text = 'CONNECTING...';
        icon = Icons.bluetooth_searching;
        break;
      case BluetoothConnectionState.scanning:
        color = AppTheme.accentCyan;
        text = 'SCANNING';
        icon = Icons.radar;
        break;
      case BluetoothConnectionState.error:
        color = AppTheme.danger;
        text = 'ERROR';
        icon = Icons.error_outline;
        break;
      default:
        color = AppTheme.textDim;
        text = 'READY';
        icon = Icons.bluetooth;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        border: Border(
          bottom: BorderSide(color: color.withOpacity(0.2)),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.accentCyan.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'AES-256 ENCRYPTED',
              style: TextStyle(
                color: AppTheme.accentCyan.withOpacity(0.7),
                fontSize: 9,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanButton(BluetoothService service) {
    return GlowContainer(
      child: InkWell(
        onTap: service.isDiscovering
            ? () => service.stopDiscovery()
            : () => service.startDiscovery(),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.bgCard,
                AppTheme.bgSurface,
              ],
            ),
            border: Border.all(
              color: service.isDiscovering
                  ? AppTheme.accentCyan.withOpacity(0.5)
                  : AppTheme.borderGlow,
            ),
          ),
          child: Row(
            children: [
              if (service.isDiscovering)
                const ScanAnimation(size: 56)
              else
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.accentCyan.withOpacity(0.1),
                    border: Border.all(
                      color: AppTheme.accentCyan.withOpacity(0.4),
                    ),
                  ),
                  child: const Icon(
                    Icons.bluetooth_searching,
                    color: AppTheme.accentCyan,
                    size: 28,
                  ),
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.isDiscovering
                          ? 'SCANNING...'
                          : 'SCAN FOR DEVICES',
                      style: const TextStyle(
                        color: AppTheme.accentCyan,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      service.isDiscovering
                          ? 'Tap to stop • ${service.discoveredDevices.length} found'
                          : 'Discover nearby Bluetooth devices',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                service.isDiscovering ? Icons.stop_circle : Icons.play_circle,
                color: service.isDiscovering
                    ? AppTheme.danger
                    : AppTheme.accentCyan,
                size: 32,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 1,
            color: AppTheme.borderGlow,
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceTile(
      BuildContext context, BTDevice device, BluetoothService service) {
    final isConnecting = service.state == BluetoothConnectionState.connecting;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppTheme.bgCard,
        border: Border.all(color: AppTheme.borderGlow),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.bgSurface,
            border: Border.all(
              color: device.isPaired
                  ? AppTheme.accentTeal.withOpacity(0.5)
                  : AppTheme.borderGlow,
            ),
          ),
          child: Icon(
            device.type == 'BLE' ? Icons.bluetooth : Icons.phone_android,
            color:
                device.isPaired ? AppTheme.accentTeal : AppTheme.textSecondary,
            size: 20,
          ),
        ),
        title: Text(
          device.name,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Row(
          children: [
            Text(
              device.address,
              style: const TextStyle(
                color: AppTheme.textDim,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
            if (device.rssi != null) ...[
              const SizedBox(width: 8),
              BTSignalBars(bars: device.signalBars),
            ],
          ],
        ),
        trailing: isConnecting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.accentCyan,
                ),
              )
            : GestureDetector(
                onTap: () => _connectToDevice(context, device, service),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: AppTheme.accentCyan.withOpacity(0.5)),
                    color: AppTheme.accentCyan.withOpacity(0.08),
                  ),
                  child: const Text(
                    'CONNECT',
                    style: TextStyle(
                      color: AppTheme.accentCyan,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildDiscoveringIndicator() {
    return Center(
      child: Column(
        children: [
          const ScanAnimation(size: 80),
          const SizedBox(height: 12),
          Text(
            'SEARCHING FOR DEVICES...',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.accentCyan.withOpacity(0.6),
                  letterSpacing: 2,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(BluetoothService service) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: AppTheme.danger.withOpacity(0.1),
        border: Border.all(color: AppTheme.danger.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.danger, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              service.errorMessage ?? '',
              style: const TextStyle(color: AppTheme.danger, fontSize: 12),
            ),
          ),
          IconButton(
            onPressed: service.clearError,
            icon: const Icon(Icons.close, size: 16, color: AppTheme.danger),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Future<void> _connectToDevice(
    BuildContext context,
    BTDevice device,
    BluetoothService service,
  ) async {
    await service.stopDiscovery();
    await service.connectToDevice(device);
  }
}
