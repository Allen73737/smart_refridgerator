import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class DeviceStatusIndicator extends StatelessWidget {
  final DateTime? lastUpdated;

  const DeviceStatusIndicator({super.key, required this.lastUpdated});

  @override
  Widget build(BuildContext context) {
    bool isOnline = false;
    if (lastUpdated != null) {
      final difference = DateTime.now().difference(lastUpdated!);
      isOnline = difference.inSeconds < 15;
    }

    final color = isOnline ? Colors.greenAccent : Colors.redAccent;
    final text = isOnline ? "Online" : "Offline";

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.5),
                blurRadius: 10,
                spreadRadius: 2,
              )
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          "Device Status: $text",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ).animate(target: isOnline ? 1 : 0).fade(duration: 300.ms),
      ],
    );
  }
}

class LastUpdatedIndicator extends StatelessWidget {
  final DateTime? lastUpdated;

  const LastUpdatedIndicator({super.key, required this.lastUpdated});

  String _getRelativeTime(DateTime? time) {
    if (time == null) return "Waiting for data...";

    final difference = DateTime.now().difference(time);
    if (difference.inSeconds < 10) return "Just now";
    if (difference.inSeconds < 60) return "${difference.inSeconds} sec ago";
    if (difference.inMinutes < 60) return "${difference.inMinutes} min ago";
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      "Last Updated: ${_getRelativeTime(lastUpdated)}",
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 14,
      ),
    );
  }
}

class BackendSyncIndicator extends StatelessWidget {
  final String status;

  const BackendSyncIndicator({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    IconData iconData;
    Color color;

    switch (status) {
      case 'Synced':
        iconData = Icons.check_circle;
        color = Colors.greenAccent;
        break;
      case 'Sync Failed':
        iconData = Icons.error;
        color = Colors.redAccent;
        break;
      case 'Syncing':
      default:
        iconData = Icons.sync;
        color = Colors.blueAccent;
        break;
    }

    Widget iconWidget = Icon(iconData, color: color, size: 20);

    if (status == 'Syncing') {
      iconWidget = Center(
        child: RotationTransition(
          turns: const AlwaysStoppedAnimation(0.5), // Placeholder for true rotation
          child: iconWidget,
        ).animate(onPlay: (c) => c.repeat()).rotate(duration: 1000.ms),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        iconWidget,
        const SizedBox(width: 8),
        Text(
          "Backend Sync: $status",
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
