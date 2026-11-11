import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Input teks dengan label mengambang (floating label) dan validasi inline.
///
/// Label tidak lagi ditulis manual sebagai [Text] di atas field, sehingga
/// hierarki visual dan jarak antar field konsisten di seluruh aplikasi.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helper,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.showObscureToggle = false,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
    this.textAlign = TextAlign.start,
    this.required = false,
    this.focusNode,
    this.style,
    this.contentPadding,
    this.autofillHints,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helper;
  final String? errorText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final bool showObscureToggle;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final int? minLines;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final TextCapitalization textCapitalization;
  final TextAlign textAlign;
  final bool required;
  final FocusNode? focusNode;
  final TextStyle? style;
  final EdgeInsets? contentPadding;
  final Iterable<String>? autofillHints;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscured = widget.obscureText;

  Widget? _buildSuffixIcon() {
    if (!widget.showObscureToggle) return widget.suffixIcon;

    return IconButton(
      tooltip: _obscured ? 'Tampilkan kata sandi' : 'Sembunyikan kata sandi',
      onPressed: () => setState(() => _obscured = !_obscured),
      icon: Icon(
        _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        size: 20,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final labelText = widget.label == null
        ? null
        : (widget.required ? '${widget.label} *' : widget.label);

    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      autofocus: widget.autofocus,
      obscureText: _obscured,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      inputFormatters: widget.inputFormatters,
      textCapitalization: widget.textCapitalization,
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      maxLength: widget.maxLength,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      onTap: widget.onTap,
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      autofillHints: widget.autofillHints,
      style: widget.style ?? Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: widget.hint,
        helperText: widget.helper,
        errorText: widget.errorText,
        contentPadding: widget.contentPadding,
        prefixIcon: widget.prefixIcon == null
            ? null
            : Icon(widget.prefixIcon, size: 20),
        suffixIcon: _buildSuffixIcon(),
      ),
    );
  }
}
