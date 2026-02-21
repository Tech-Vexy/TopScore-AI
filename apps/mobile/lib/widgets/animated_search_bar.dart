import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_theme.dart';

class AnimatedSearchBar extends StatefulWidget {
  final Function(String) onSearchChanged;
  final String hintText;
  final EdgeInsets? margin;
  final IconData? prefixIcon;
  final bool autofocus;

  const AnimatedSearchBar({
    super.key,
    required this.onSearchChanged,
    this.hintText = 'Search...',
    this.margin,
    this.prefixIcon,
    this.autofocus = false,
  });

  @override
  State<AnimatedSearchBar> createState() => _AnimatedSearchBarState();
}

class _AnimatedSearchBarState extends State<AnimatedSearchBar>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  bool _isFocused = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
    _animationController = AnimationController(
      duration: AppTheme.durationNormal,
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
      if (_isFocused) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      widget.onSearchChanged(value);
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedContainer(
      duration: AppTheme.durationNormal,
      margin: widget.margin,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: _isFocused
              ? theme.colorScheme.primary
              : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: _isFocused
                ? theme.colorScheme.primary.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: _isFocused ? 12 : 10,
            offset: Offset(0, _isFocused ? 4 : 3),
          ),
        ],
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        onChanged: _onSearchChanged,
        autofocus: widget.autofocus,
        style: GoogleFonts.nunito(
          color: theme.colorScheme.onSurface,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: GoogleFonts.nunito(
            color: theme.hintColor,
            fontSize: 16,
          ),
          prefixIcon: AnimatedSwitcher(
            duration: AppTheme.durationFast,
            child: Icon(
              widget.prefixIcon ?? Icons.search,
              key: ValueKey(_isFocused),
              color: _isFocused
                  ? theme.colorScheme.primary
                  : theme.iconTheme.color,
              size: 22,
            ),
          ),
          suffixIcon: _controller.text.isNotEmpty
              ? ScaleTransition(
                  scale: _scaleAnimation,
                  child: IconButton(
                    icon: Icon(
                      Icons.clear,
                      size: 20,
                      color: theme.iconTheme.color?.withValues(alpha: 0.7),
                    ),
                    onPressed: () {
                      _controller.clear();
                      _debounce?.cancel();
                      widget.onSearchChanged('');
                      setState(() {});
                    },
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: AppTheme.spacingMd,
            horizontal: AppTheme.spacingMd,
          ),
        ),
      ),
    );
  }
}
