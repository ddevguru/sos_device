import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/ble_service.dart';

class IotStatusBadge extends StatelessWidget {
  final BleConnectionStatus status;
  final String? deviceName;
  final VoidCallback onTap;

  const IotStatusBadge({
    Key? key,
    required this.status,
    this.deviceName,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    String statusText;
    IconData icon;

    switch (status) {
      case BleConnectionStatus.connected:
        badgeColor = AppTheme.accentGreen;
        statusText = deviceName ?? 'IoT Button Connected';
        icon = Icons.bluetooth_connected_rounded;
        break;
      case BleConnectionStatus.connecting:
      case BleConnectionStatus.scanning:
        badgeColor = AppTheme.accentAmber;
        statusText = 'Scanning for IoT Button...';
        icon = Icons.bluetooth_searching_rounded;
        break;
      case BleConnectionStatus.error:
      case BleConnectionStatus.disconnected:
      default:
        badgeColor = AppTheme.textMuted;
        statusText = 'No IoT Button Paired';
        icon = Icons.bluetooth_disabled_rounded;
        break;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: badgeColor.withOpacity(0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: badgeColor,
                boxShadow: [
                  BoxShadow(
                    color: badgeColor.withOpacity(0.6),
                    blurRadius: 6,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(icon, size: 18, color: badgeColor),
            const SizedBox(width: 8),
            Text(
              statusText,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: badgeColor,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}
