import 'package:flutter/material.dart';
import '../../../core/services/network_interface_helper.dart';

class NetworkInterfaceSelector extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String helperText;

  const NetworkInterfaceSelector({
    super.key,
    required this.controller,
    this.labelText = '绑定网卡 / Wi-Fi (bind_interface，可选)',
    this.helperText = '可自动识别已连接的 Wi-Fi 与物理网卡，指定节点从此通道发出',
  });

  @override
  State<NetworkInterfaceSelector> createState() => _NetworkInterfaceSelectorState();
}

class _NetworkInterfaceSelectorState extends State<NetworkInterfaceSelector> {
  List<DetectedNetworkInterface> _interfaces = [];
  bool _isLoading = true;
  bool _isCustomMode = false;

  @override
  void initState() {
    super.initState();
    _loadInterfaces();
  }

  Future<void> _loadInterfaces() async {
    setState(() => _isLoading = true);
    final list = await NetworkInterfaceHelper.getActiveInterfaces();
    if (!mounted) return;

    final currentVal = widget.controller.text.trim();
    final hasMatch = currentVal.isEmpty || list.any((item) => item.name == currentVal);

    setState(() {
      _interfaces = list;
      _isLoading = false;
      if (!hasMatch && currentVal.isNotEmpty) {
        _isCustomMode = true;
      }
    });
  }

  IconData _getIconForInterface(DetectedNetworkInterface iface) {
    if (iface.isWifi) return Icons.wifi_rounded;
    if (iface.isEthernet) return Icons.settings_ethernet_rounded;
    if (iface.isVirtual) return Icons.vpn_lock_rounded;
    return Icons.device_hub_rounded;
  }

  Color _getColorForInterface(DetectedNetworkInterface iface) {
    if (iface.isWifi) return const Color(0xFF38BDF8);
    if (iface.isEthernet) return const Color(0xFF34D399);
    if (iface.isVirtual) return const Color(0xFF94A3B8);
    return const Color(0xFF818CF8);
  }

  @override
  Widget build(BuildContext context) {
    final currentText = widget.controller.text.trim();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final mutedTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 10),
            Text('正在自动扫描本机网卡与 Wi-Fi 接口...', style: TextStyle(fontSize: 12, color: mutedTextColor)),
          ],
        ),
      );
    }

    if (_isCustomMode) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: widget.controller,
            decoration: InputDecoration(
              labelText: widget.labelText,
              hintText: '例如: Wi-Fi、Wi-Fi 2、WLAN 或以太网',
              helperText: widget.helperText,
              prefixIcon: const Icon(Icons.edit_note_rounded, size: 18),
              suffixIcon: IconButton(
                icon: const Icon(Icons.list_alt_rounded, size: 18),
                tooltip: '返回已识别网卡列表',
                onPressed: () {
                  setState(() => _isCustomMode = false);
                },
              ),
            ),
          ),
        ],
      );
    }

    // Determine current dropdown value
    final knownNames = _interfaces.map((e) => e.name).toSet();
    final dropdownValue = knownNames.contains(currentText) ? currentText : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey('${_interfaces.length}_$dropdownValue'),
                initialValue: dropdownValue,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: widget.labelText,
                  helperText: widget.helperText,
                  prefixIcon: Icon(
                    dropdownValue.isEmpty
                        ? Icons.language_rounded
                        : () {
                            final match = _interfaces.where((e) => e.name == dropdownValue);
                            return match.isNotEmpty ? _getIconForInterface(match.first) : Icons.wifi_rounded;
                          }(),
                    size: 18,
                    color: const Color(0xFF818CF8),
                  ),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: '',
                    child: Row(
                      children: [
                        Icon(Icons.language_rounded, size: 16, color: Color(0xFF94A3B8)),
                        SizedBox(width: 8),
                        Text('🌐 默认（跟随系统路由，不绑定特定网卡）', style: TextStyle(fontSize: 12.5)),
                      ],
                    ),
                  ),
                  ..._interfaces.map((iface) {
                    final color = _getColorForInterface(iface);
                    final icon = _getIconForInterface(iface);
                    final typeLabel = iface.isWifi ? 'Wi-Fi' : (iface.isEthernet ? '以太网' : '网卡');

                    return DropdownMenuItem<String>(
                      value: iface.name,
                      child: Row(
                        children: [
                          Icon(icon, size: 16, color: color),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RichText(
                              overflow: TextOverflow.ellipsis,
                              text: TextSpan(
                                text: iface.name,
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: primaryTextColor),
                                children: [
                                  TextSpan(
                                    text: ' [$typeLabel${iface.primaryIp.isNotEmpty ? ' • ${iface.primaryIp}' : ''}]',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: color),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const DropdownMenuItem<String>(
                    value: '__CUSTOM__',
                    child: Row(
                      children: [
                        Icon(Icons.edit_rounded, size: 16, color: Color(0xFFF59E0B)),
                        SizedBox(width: 8),
                        Text('✏️ 自定义输入网卡名称...', style: TextStyle(fontSize: 12.5, color: Color(0xFFFBBF24))),
                      ],
                    ),
                  ),
                ],
                onChanged: (val) {
                  if (val == '__CUSTOM__') {
                    setState(() => _isCustomMode = true);
                  } else {
                    setState(() {
                      widget.controller.text = val ?? '';
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              tooltip: '重新扫描本机网卡与 Wi-Fi',
              color: const Color(0xFF818CF8),
              onPressed: _loadInterfaces,
            ),
          ],
        ),
      ],
    );
  }
}
