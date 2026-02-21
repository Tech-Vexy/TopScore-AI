import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_theme.dart';

enum ButtonVariant { primary, secondary, outline, ghost, danger }
enum ButtonSize { small, medium, large }

class EnhancedButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final ButtonSize size;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;
  final Color? customColor;

  const EnhancedButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.fullWidth = false,
    this.customColor,
  });

  @override
  State<EnhancedButton> createState() => _EnhancedButtonState();
}

class _EnhancedButtonState extends State<EnhancedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppTheme.durationFast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled = widget.onPressed != null && !widget.isLoading;

    // Size configurations
    double height;
    double horizontalPadding;
    double fontSize;
    double iconSize;

    switch (widget.size) {
      case ButtonSize.small:
        height = 36;
        horizontalPadding = AppTheme.spacingMd;
        fontSize = 14;
        iconSize = 16;
        break;
      case ButtonSize.large:
        height = 56;
        horizontalPadding = AppTheme.spacingXl;
        fontSize = 18;
        iconSize = 24;
        break;
      case ButtonSize.medium:
        height = 48;
        horizontalPadding = AppTheme.spacingLg;
        fontSize = 16;
        iconSize = 20;
        break;
    }

    return GestureDetector(
      onTapDown: isEnabled ? _handleTapDown : null,
      onTapUp: isEnabled ? _handleTapUp : null,
      onTapCancel: isEnabled ? _handleTapCancel : null,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: AppTheme.durationNormal,
          height: height,
          width: widget.fullWidth ? double.infinity : null,
          child: ElevatedButton(
            onPressed: isEnabled ? widget.onPressed : null,
            style: _getButtonStyle(theme, height, horizontalPadding),
            child: widget.isLoading
                ? SizedBox(
                    height: iconSize,
                    width: iconSize,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getTextColor(theme),
                      ),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, size: iconSize),
                        SizedBox(width: AppTheme.spacingSm),
                      ],
                      Text(
                        widget.text,
                        style: GoogleFonts.nunito(
                          fontSize: fontSize,
                          fontWeight: FontWeight.w700,
                          color: _getTextColor(theme),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  ButtonStyle _getButtonStyle(ThemeData theme, double height, double padding) {
    final baseColor = widget.customColor ?? theme.colorScheme.primary;

    switch (widget.variant) {
      case ButtonVariant.primary:
        return ElevatedButton.styleFrom(
          backgroundColor: baseColor,
          foregroundColor: Colors.white,
          elevation: AppTheme.elevationSm,
          shadowColor: baseColor.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          padding: EdgeInsets.symmetric(horizontal: padding),
        );

      case ButtonVariant.secondary:
        return ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.secondary,
          foregroundColor: Colors.white,
          elevation: AppTheme.elevationSm,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          padding: EdgeInsets.symmetric(horizontal: padding),
        );

      case ButtonVariant.outline:
        return ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: baseColor,
          elevation: 0,
          side: BorderSide(color: baseColor, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          padding: EdgeInsets.symmetric(horizontal: padding),
        );

      case ButtonVariant.ghost:
        return ElevatedButton.styleFrom(
          backgroundColor: baseColor.withValues(alpha: 0.1),
          foregroundColor: baseColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          padding: EdgeInsets.symmetric(horizontal: padding),
        );

      case ButtonVariant.danger:
        return ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.error,
          foregroundColor: Colors.white,
          elevation: AppTheme.elevationSm,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          padding: EdgeInsets.symmetric(horizontal: padding),
        );
    }
  }

  Color _getTextColor(ThemeData theme) {
    switch (widget.variant) {
      case ButtonVariant.outline:
      case ButtonVariant.ghost:
        return widget.customColor ?? theme.colorScheme.primary;
      default:
        return Colors.white;
    }
  }
}
