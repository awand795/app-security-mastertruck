import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';

enum AppButtonVariant { primary, secondary, danger, ghost }

enum AppButtonSize { medium, large }

/// Tombol utama aplikasi.
///
/// - [AppButtonVariant.primary] : aksi utama (navy di light, amber di dark)
/// - [AppButtonVariant.secondary] : aksi pendamping (outline)
/// - [AppButtonVariant.danger] : aksi destruktif (merah)
/// - [AppButtonVariant.ghost] : aksi tanpa latar
///
/// Semua varian memiliki tinggi minimum 48-54 px dan animasi tekan halus.
class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.large,
    this.loading = false,
    this.loadingLabel,
    this.expanded = true,
    this.haptic,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailingIcon;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool loading;
  final String? loadingLabel;
  final bool expanded;

  /// Default: aktif untuk primary & danger, nonaktif untuk varian lain.
  final bool? haptic;
  final String? semanticLabel;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  bool get _shouldHaptic =>
      widget.haptic ??
      (widget.variant == AppButtonVariant.primary ||
          widget.variant == AppButtonVariant.danger);

  double get _height => widget.size == AppButtonSize.large ? 54 : 48;

  Future<void> _fireHaptic() async {
    if (!_shouldHaptic) return;
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {
      // Perangkat tanpa dukungan haptic diabaikan.
    }
  }

  void _handleTap() {
    if (!_enabled) return;
    unawaited(_fireHaptic());
    widget.onPressed?.call();
  }

  void _setPressed(bool value) {
    if (!_enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    );
    final padding = EdgeInsets.symmetric(
      horizontal: widget.size == AppButtonSize.large ? 20 : 16,
      vertical: 12,
    );

    final Color foreground;
    final Color? background;
    final BorderSide? side;

    switch (widget.variant) {
      case AppButtonVariant.primary:
        foreground = scheme.onPrimary;
        background = scheme.primary;
        side = null;
        break;
      case AppButtonVariant.danger:
        if (Theme.of(context).brightness == Brightness.dark) {
          foreground = scheme.onErrorContainer;
          background = scheme.errorContainer;
        } else {
          foreground = scheme.onError;
          background = scheme.error;
        }
        side = null;
        break;
      case AppButtonVariant.secondary:
        foreground = scheme.onSurface;
        background = null;
        side = BorderSide(color: scheme.outline, width: 1.5);
        break;
      case AppButtonVariant.ghost:
        foreground = scheme.primary;
        background = null;
        side = BorderSide.none;
        break;
    }

    final disabledForeground = scheme.onSurface.withValues(alpha: 0.38);
    final disabledBackground = scheme.onSurface.withValues(alpha: 0.12);

    final buttonStyle =
        (background != null
                ? FilledButton.styleFrom(
                    backgroundColor: background,
                    foregroundColor: foreground,
                    disabledBackgroundColor: disabledBackground,
                    disabledForegroundColor: disabledForeground,
                    elevation: 0,
                  )
                : OutlinedButton.styleFrom(
                    foregroundColor: foreground,
                    disabledForegroundColor: disabledForeground,
                    backgroundColor: widget.variant == AppButtonVariant.ghost
                        ? Colors.transparent
                        : null,
                    side: side,
                  ))
            .merge(
              ButtonStyle(
                minimumSize: WidgetStatePropertyAll(Size(64, _height)),
                padding: WidgetStatePropertyAll(padding),
                shape: WidgetStatePropertyAll(shape),
                textStyle: WidgetStatePropertyAll(
                  Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: widget.size == AppButtonSize.large ? 15 : 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
            );

    final content = Row(
      mainAxisSize: widget.expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.loading) ...[
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(
                _enabled ? foreground : disabledForeground,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
        ] else if (widget.icon != null) ...[
          Icon(
            widget.icon,
            size: 20,
            color: _enabled ? foreground : disabledForeground,
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
        Flexible(
          child: Text(
            widget.loading
                ? (widget.loadingLabel ?? 'Memproses')
                : widget.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
        if (!widget.loading && widget.trailingIcon != null) ...[
          const SizedBox(width: AppSpacing.xs),
          Icon(
            widget.trailingIcon,
            size: 20,
            color: _enabled ? foreground : disabledForeground,
          ),
        ],
      ],
    );

    Widget button;
    if (background != null) {
      button = FilledButton(
        onPressed: _enabled ? _handleTap : null,
        style: buttonStyle,
        child: content,
      );
    } else {
      button = OutlinedButton(
        onPressed: _enabled ? _handleTap : null,
        style: buttonStyle,
        child: content,
      );
    }

    Widget result = Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: AppDurations.fast,
        curve: Curves.easeOut,
        child: button,
      ),
    );

    if (widget.expanded) {
      result = SizedBox(width: double.infinity, child: result);
    }

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.semanticLabel ?? widget.label,
      child: ExcludeSemantics(child: result),
    );
  }
}
