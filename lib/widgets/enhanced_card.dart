import 'package:flutter/material.dart';
import '../config/app_theme.dart';

class EnhancedCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color? color;
  final Gradient? gradient;
  final double? elevation;
  final double? borderRadius;
  final Border? border;
  final bool enableHoverEffect;
  final bool enablePressEffect;

  const EnhancedCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.color,
    this.gradient,
    this.elevation,
    this.borderRadius,
    this.border,
    this.enableHoverEffect = true,
    this.enablePressEffect = true,
  });

  @override
  State<EnhancedCard> createState() => _EnhancedCardState();
}

class _EnhancedCardState extends State<EnhancedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppTheme.durationFast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _elevationAnimation = Tween<double>(
      begin: widget.elevation ?? AppTheme.elevationSm,
      end: (widget.elevation ?? AppTheme.elevationSm) + 4,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.enablePressEffect && widget.onTap != null) {
      _controller.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.enablePressEffect && widget.onTap != null) {
      _controller.reverse();
    }
  }

  void _handleTapCancel() {
    if (widget.enablePressEffect && widget.onTap != null) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = widget.color ?? theme.cardColor;
    final radius = widget.borderRadius ?? AppTheme.radiusLg;

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onTap,
      child: MouseRegion(
        onEnter: (_) {
          if (widget.enableHoverEffect && widget.onTap != null) {
            setState(() => _isHovered = true);
          }
        },
        onExit: (_) {
          if (widget.enableHoverEffect && widget.onTap != null) {
            setState(() => _isHovered = false);
          }
        },
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: widget.enablePressEffect ? _scaleAnimation.value : 1.0,
              child: AnimatedContainer(
                duration: AppTheme.durationNormal,
                margin: widget.margin,
                decoration: BoxDecoration(
                  color: widget.gradient == null ? cardColor : null,
                  gradient: widget.gradient,
                  borderRadius: BorderRadius.circular(radius),
                  border: widget.border,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: theme.brightness == Brightness.dark ? 0.3 : 0.08,
                      ),
                      blurRadius: _isHovered && widget.enableHoverEffect
                          ? _elevationAnimation.value * 2
                          : (widget.elevation ?? AppTheme.elevationSm) * 2,
                      offset: Offset(
                        0,
                        _isHovered && widget.enableHoverEffect
                            ? _elevationAnimation.value / 2
                            : (widget.elevation ?? AppTheme.elevationSm) / 2,
                      ),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(radius),
                  child: Material(
                    color: Colors.transparent,
                    child: Padding(
                      padding: widget.padding ??
                          const EdgeInsets.all(AppTheme.spacingMd),
                      child: widget.child,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
