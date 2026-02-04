import 'package:flutter/material.dart';
import '../tutor_client/connection_manager.dart' as conn;

/// Visual indicator for connection status and quality
class ConnectionStatusIndicator extends StatelessWidget {
  final conn.ConnectionStateManager connectionManager;
  final bool showLabel;
  final double size;

  const ConnectionStatusIndicator({
    super.key,
    required this.connectionManager,
    this.showLabel = false,
    this.size = 12,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<conn.ConnectionState>(
      stream: connectionManager.stateStream,
      initialData: connectionManager.currentState,
      builder: (context, snapshot) {
        final state = snapshot.data ?? conn.ConnectionState.disconnected;
        final quality = connectionManager.getConnectionQuality();
        final latency = connectionManager.latencyMs;

        final color = _getColorForQuality(quality, state);
        final icon = _getIconForState(state);
        final label = _getLabelForState(state, quality, latency);

        return Tooltip(
          message: label,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: state == conn.ConnectionState.connected
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.5),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Icon(
                    icon,
                    size: size * 0.6,
                    color: Colors.white,
                  ),
                ),
              ),
              if (showLabel) ...[
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Color _getColorForQuality(
    conn.ConnectionQuality quality,
    conn.ConnectionState state,
  ) {
    if (state == conn.ConnectionState.offline) return Colors.grey;
    if (state == conn.ConnectionState.connecting ||
        state == conn.ConnectionState.reconnecting) {
      return Colors.orange;
    }

    switch (quality) {
      case conn.ConnectionQuality.excellent:
        return Colors.green;
      case conn.ConnectionQuality.good:
        return Colors.lightGreen;
      case conn.ConnectionQuality.fair:
        return Colors.orange;
      case conn.ConnectionQuality.poor:
        return Colors.red;
    }
  }

  IconData _getIconForState(conn.ConnectionState state) {
    switch (state) {
      case conn.ConnectionState.connected:
        return Icons.check;
      case conn.ConnectionState.connecting:
      case conn.ConnectionState.reconnecting:
        return Icons.sync;
      case conn.ConnectionState.disconnected:
      case conn.ConnectionState.offline:
        return Icons.close;
    }
  }

  String _getLabelForState(
    conn.ConnectionState state,
    conn.ConnectionQuality quality,
    int latency,
  ) {
    if (state == conn.ConnectionState.offline) return 'Offline';
    if (state == conn.ConnectionState.connecting) return 'Connecting...';
    if (state == conn.ConnectionState.reconnecting) return 'Reconnecting...';
    if (state == conn.ConnectionState.disconnected) return 'Disconnected';

    // Connected state - show quality
    final qualityText = switch (quality) {
      conn.ConnectionQuality.excellent => 'Excellent',
      conn.ConnectionQuality.good => 'Good',
      conn.ConnectionQuality.fair => 'Fair',
      conn.ConnectionQuality.poor => 'Poor',
    };

    return '$qualityText ($latency ms)';
  }
}

/// Data saver mode indicator and toggle
class DataSaverIndicator extends StatelessWidget {
  final conn.ConnectionStateManager connectionManager;
  final VoidCallback? onToggle;

  const DataSaverIndicator({
    super.key,
    required this.connectionManager,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isMetered = connectionManager.isMetered;
    final dataSaverEnabled = connectionManager.dataSaverMode;

    if (!isMetered && !dataSaverEnabled) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isMetered ? Icons.signal_cellular_alt : Icons.data_saver_on,
            size: 16,
            color: Colors.orange,
          ),
          const SizedBox(width: 6),
          Text(
            isMetered ? 'Mobile Data' : 'Data Saver',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.orange,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (onToggle != null) ...[
            const SizedBox(width: 8),
            Switch(
              value: dataSaverEnabled,
              onChanged: (value) {
                connectionManager.setDataSaverMode(value);
                onToggle?.call();
              },
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ],
      ),
    );
  }
}
