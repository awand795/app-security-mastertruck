import 'dart:async';

import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Kolom pencarian dengan debounce 400 ms.
///
/// Mengetik tidak memicu request tiap huruf. Bila [isSearching] aktif,
/// tampilkan indikator tipis (bukan spinner penuh) agar daftar tetap terlihat.
class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    required this.onChanged,
    this.controller,
    this.hintText = 'Cari…',
    this.onSubmitted,
    this.onClear,
    this.autofocus = false,
    this.enabled = true,
    this.isSearching = false,
    this.debounce = const Duration(milliseconds: 400),
  });

  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final bool autofocus;
  final bool enabled;
  final bool isSearching;
  final Duration debounce;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  TextEditingController? _internalController;
  Timer? _debounceTimer;

  TextEditingController get _controller =>
      widget.controller ?? _internalController!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _internalController = TextEditingController();
    }
    _controller.addListener(_handleTextChanged);
  }

  @override
  void didUpdateWidget(covariant SearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _controller.removeListener(_handleTextChanged);
      if (widget.controller == null) {
        _internalController = TextEditingController();
      } else {
        _internalController?.dispose();
        _internalController = null;
      }
      _controller.addListener(_handleTextChanged);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.removeListener(_handleTextChanged);
    _internalController?.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    if (mounted) setState(() {});
  }

  void _handleChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(widget.debounce, () {
      widget.onChanged(value.trim());
    });
  }

  void _handleSubmitted(String value) {
    _debounceTimer?.cancel();
    final query = value.trim();
    widget.onChanged(query);
    widget.onSubmitted?.call(query);
  }

  void _handleClear() {
    _debounceTimer?.cancel();
    _controller.clear();
    widget.onChanged('');
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasText = _controller.text.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          textInputAction: TextInputAction.search,
          autocorrect: false,
          onChanged: _handleChanged,
          onSubmitted: _handleSubmitted,
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          style: Theme.of(context).textTheme.bodyMedium,
          decoration: InputDecoration(
            hintText: widget.hintText,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            prefixIcon: Icon(
              Icons.search_rounded,
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
            suffixIcon: hasText
                ? IconButton(
                    tooltip: 'Hapus pencarian',
                    onPressed: _handleClear,
                    icon: const Icon(Icons.close_rounded, size: 20),
                  )
                : null,
          ),
        ),
        if (widget.isSearching) ...[
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: const LinearProgressIndicator(minHeight: 2),
          ),
        ],
      ],
    );
  }
}
