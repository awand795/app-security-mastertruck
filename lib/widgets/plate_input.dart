import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../utils/plate_utils.dart';

/// Kolom input nomor polisi bergaya plat fisik.
///
/// Dipakai di layar check-in dan check-out agar identitas kendaraan selalu
/// menjadi fokus utama. Teks memakai Chivo dari [AppTheme.plateStyle].
class PlateInput extends StatefulWidget {
  const PlateInput({
    super.key,
    required this.controller,
    this.onSubmitted,
    this.onChanged,
    this.onClear,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
    this.hintText = 'B 2156 TQR',
  });

  final TextEditingController controller;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final bool enabled;
  final bool autofocus;
  final FocusNode? focusNode;
  final String hintText;

  @override
  State<PlateInput> createState() => _PlateInputState();
}

class _PlateInputState extends State<PlateInput> {
  FocusNode? _internalFocusNode;
  FocusNode get _effectiveFocusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _effectiveFocusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(PlateInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      oldWidget.focusNode?.removeListener(_onFocusChange);
      _internalFocusNode?.removeListener(_onFocusChange);
      _effectiveFocusNode.addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    _effectiveFocusNode.removeListener(_onFocusChange);
    _internalFocusNode?.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted && _isFocused != _effectiveFocusNode.hasFocus) {
      setState(() => _isFocused = _effectiveFocusNode.hasFocus);
    }
  }

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    final scheme = Theme.of(context).colorScheme;

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (context, value, _) {
        final hasText = value.text.isNotEmpty;

        return AnimatedContainer(
          duration: AppDurations.fast,
          decoration: BoxDecoration(
            color: semantic.plateBackground,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: _isFocused ? scheme.primary : semantic.plateBorder,
              width: _isFocused ? 2.0 : 1.5,
            ),
            boxShadow: AppShadows.soft(context),
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _effectiveFocusNode,
            enabled: widget.enabled,
            autofocus: widget.autofocus,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.search,
            inputFormatters: [PlateInputFormatter()],
            textAlign: TextAlign.center,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            cursorColor: scheme.primary,
            style: AppTheme.plateStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
            ).copyWith(color: semantic.plateForeground),
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle:
                  AppTheme.plateStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                  ).copyWith(
                    color: semantic.plateForeground.withValues(alpha: 0.32),
                  ),
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              contentPadding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                18,
                56,
                18,
              ),
              suffixIcon: hasText && widget.enabled
                  ? IconButton(
                      tooltip: 'Hapus nomor polisi',
                      onPressed: () {
                        widget.controller.clear();
                        widget.onClear?.call();
                      },
                      icon: Icon(
                        Icons.cancel_rounded,
                        size: 22,
                        color: semantic.plateForeground.withValues(alpha: 0.55),
                      ),
                    )
                  : null,
            ),
          ),
        );
      },
    );
  }
}
