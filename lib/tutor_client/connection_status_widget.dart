import 'package:flutter/material.dart';
import 'connection_manager.dart' as cm;

/// Widget that displays the current connection status
class ConnectionStatusBanner extends StatelessWidget {
  final cm.ConnectionState state;
  final VoidCallback? onRetry;
  final int? pendingMessages;

  const ConnectionStatusBanner({
    super.key,
    required this.state,
    this.onRetry,
    this.pendingMessages,
  });

  @override
  Widget build(BuildContext context) {
    if (state == cm.ConnectionState.connected) {
      return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            _buildIcon(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getTitle(),
                    style: TextStyle(
                      color: _getTextColor(),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  if (_getSubtitle() != null)
                    Text(
                      _getSubtitle()!,
                      style: TextStyle(
                        color: _getTextColor().withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            if (onRetry != null && state == cm.ConnectionState.disconnected)
              TextButton(
                onPressed: onRetry,
                child: Text(
                  'Retry',
                  style: TextStyle(
                    color: _getTextColor(),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (state == cm.ConnectionState.connecting ||
                state == cm.ConnectionState.reconnecting)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(_getTextColor()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    IconData icon;
    switch (state) {
      case cm.ConnectionState.connecting:
      case cm.ConnectionState.reconnecting:
        icon = Icons.sync;
        break;
      case cm.ConnectionState.offline:
        icon = Icons.wifi_off;
        break;
      case cm.ConnectionState.disconnected:
        icon = Icons.cloud_off;
        break;
      default:
        icon = Icons.cloud_done;
    }

    return Icon(icon, color: _getTextColor(), size: 20);
  }

  Color _getBackgroundColor() {
    switch (state) {
      case cm.ConnectionState.connecting:
      case cm.ConnectionState.reconnecting:
        return Colors.blue.shade600;
      case cm.ConnectionState.offline:
        return Colors.grey.shade700;
      case cm.ConnectionState.disconnected:
        return Colors.orange.shade600;
      default:
        return Colors.green.shade600;
    }
  }

  Color _getTextColor() => Colors.white;

  String _getTitle() {
    switch (state) {
      case cm.ConnectionState.connecting:
        return 'Connecting...';
      case cm.ConnectionState.reconnecting:
        return 'Reconnecting...';
      case cm.ConnectionState.offline:
        return 'No Internet Connection';
      case cm.ConnectionState.disconnected:
        return 'Connection Lost';
      default:
        return 'Connected';
    }
  }

  String? _getSubtitle() {
    if (pendingMessages != null && pendingMessages! > 0) {
      return '$pendingMessages message${pendingMessages! > 1 ? 's' : ''} pending';
    }
    if (state == cm.ConnectionState.offline) {
      return 'Messages will be sent when online';
    }
    return null;
  }
}

/// Animated connection indicator dot
class ConnectionIndicator extends StatefulWidget {
  final cm.ConnectionState state;
  final double size;

  const ConnectionIndicator({super.key, required this.state, this.size = 10});

  @override
  State<ConnectionIndicator> createState() => _ConnectionIndicatorState();
}

class _ConnectionIndicatorState extends State<ConnectionIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _updateAnimation();
  }

  @override
  void didUpdateWidget(ConnectionIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _updateAnimation();
    }
  }

  void _updateAnimation() {
    if (widget.state == cm.ConnectionState.connecting ||
        widget.state == cm.ConnectionState.reconnecting) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _getColor().withOpacity(_animation.value),
            boxShadow: [
              BoxShadow(
                color: _getColor().withOpacity(0.4),
                blurRadius: widget.size / 2,
                spreadRadius: widget.size / 4,
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getColor() {
    switch (widget.state) {
      case cm.ConnectionState.connected:
        return Colors.green;
      case cm.ConnectionState.connecting:
      case cm.ConnectionState.reconnecting:
        return Colors.blue;
      case cm.ConnectionState.offline:
        return Colors.grey;
      case cm.ConnectionState.disconnected:
        return Colors.orange;
    }
  }
}

/// Stream builder wrapper for connection state
class ConnectionStateBuilder extends StatelessWidget {
  final Widget Function(BuildContext, cm.ConnectionState) builder;

  const ConnectionStateBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<cm.ConnectionState>(
      stream: cm.ConnectionStateManager().stateStream,
      initialData: cm.ConnectionStateManager().currentState,
      builder: (context, snapshot) {
        return builder(
          context,
          snapshot.data ?? cm.ConnectionState.disconnected,
        );
      },
    );
  }
}
