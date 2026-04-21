class BTDevice {
  final String name;
  final String address;
  final String type;
  final int? rssi;
  final bool isPaired;

  BTDevice({
    required this.name,
    required this.address,
    required this.type,
    this.rssi,
    this.isPaired = false,
  });

  String get signalStrength {
    if (rssi == null) return '';
    if (rssi! >= -60) return 'Strong';
    if (rssi! >= -70) return 'Good';
    if (rssi! >= -80) return 'Fair';
    return 'Weak';
  }

  int get signalBars {
    if (rssi == null) return 0;
    if (rssi! >= -60) return 4;
    if (rssi! >= -70) return 3;
    if (rssi! >= -80) return 2;
    return 1;
  }
}
