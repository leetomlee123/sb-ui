import 'dart:io';
import 'package:flutter/foundation.dart';

class DetectedNetworkInterface {
  final String name;
  final List<String> ipAddresses;
  final bool isWifi;
  final bool isEthernet;
  final bool isVirtual;

  const DetectedNetworkInterface({
    required this.name,
    required this.ipAddresses,
    this.isWifi = false,
    this.isEthernet = false,
    this.isVirtual = false,
  });

  String get primaryIp => ipAddresses.isNotEmpty ? ipAddresses.first : '';

  String get displayName {
    if (ipAddresses.isEmpty) return name;
    return '$name ($primaryIp)';
  }

  @override
  String toString() => displayName;
}

class NetworkInterfaceHelper {
  /// Fetches all active physical and virtual network interfaces on the local machine.
  static Future<List<DetectedNetworkInterface>> getActiveInterfaces() async {
    try {
      final rawInterfaces = await NetworkInterface.list(
        includeLoopback: false,
        includeLinkLocal: false,
        type: InternetAddressType.any,
      );

      final List<DetectedNetworkInterface> results = [];

      for (final iface in rawInterfaces) {
        final name = iface.name.trim();
        if (name.isEmpty) continue;

        final ips = iface.addresses
            .where((addr) => !addr.isLoopback && !addr.isLinkLocal)
            .map((addr) => addr.address)
            .toList();

        final lowerName = name.toLowerCase();

        final isWifi = lowerName.contains('wi-fi') ||
            lowerName.contains('wifi') ||
            lowerName.contains('wlan') ||
            lowerName.contains('wireless') ||
            lowerName.contains('802.11');

        final isEthernet = lowerName.contains('以太网') ||
            lowerName.contains('ethernet') ||
            lowerName.contains('eth') ||
            lowerName.contains('en0') ||
            lowerName.contains('local area connection');

        final isVirtual = lowerName.contains('tun') ||
            lowerName.contains('tap') ||
            lowerName.contains('singbox') ||
            lowerName.contains('wintun') ||
            lowerName.contains('docker') ||
            lowerName.contains('vEthernet'.toLowerCase()) ||
            lowerName.contains('vmware') ||
            lowerName.contains('virtual');

        results.add(DetectedNetworkInterface(
          name: name,
          ipAddresses: ips,
          isWifi: isWifi,
          isEthernet: isEthernet,
          isVirtual: isVirtual,
        ));
      }

      // Sort: Physical Wi-Fi and Ethernet first, then others, virtual last
      results.sort((a, b) {
        if (a.isVirtual != b.isVirtual) {
          return a.isVirtual ? 1 : -1;
        }
        if (a.isWifi != b.isWifi) {
          return a.isWifi ? -1 : 1;
        }
        if (a.isEthernet != b.isEthernet) {
          return a.isEthernet ? -1 : 1;
        }
        return a.name.compareTo(b.name);
      });

      return results;
    } catch (e) {
      if (kDebugMode) {
        print('[NetworkInterfaceHelper] Failed to enumerate interfaces: $e');
      }
      return [];
    }
  }
}
