import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../config/theme.dart';

/// Merender konten HTML atau `<iframe>` dari database (`iklan_apk` / `panduan_apk`)
/// menggunakan WebView native. Aman di widget test headless saat WebViewPlatform null.
class HtmlIframeBox extends StatefulWidget {
  const HtmlIframeBox({
    super.key,
    required this.htmlContent,
    this.fallbackTitle = '',
    this.height = 190,
    this.backgroundColor = Colors.transparent,
  });

  final String htmlContent;
  final String fallbackTitle;
  final double height;
  final Color backgroundColor;

  @override
  State<HtmlIframeBox> createState() => _HtmlIframeBoxState();
}

class _HtmlIframeBoxState extends State<HtmlIframeBox> {
  WebViewController? _controller;

  bool get _hasWebViewPlatform => WebViewPlatform.instance != null;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  @override
  void didUpdateWidget(covariant HtmlIframeBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.htmlContent != widget.htmlContent) {
      _loadHtml();
    }
  }

  String _wrapHtml(String raw) {
    final trimmed = raw.trim();
    if (trimmed.toLowerCase().contains('<html')) {
      return trimmed;
    }
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    html, body {
      margin: 0;
      padding: 0;
      width: 100%;
      height: 100%;
      background: transparent;
      overflow-x: hidden;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    }
    iframe {
      width: 100%;
      height: 100%;
      border: 0;
      display: block;
    }
  </style>
</head>
<body>$trimmed</body>
</html>
''';
  }

  void _initController() {
    if (!_hasWebViewPlatform) return;
    final ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(widget.backgroundColor);
    _controller = ctrl;
    _loadHtml();
  }

  void _loadHtml() {
    final ctrl = _controller;
    if (ctrl == null) return;
    ctrl.loadHtmlString(_wrapHtml(widget.htmlContent));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;

    if (!_hasWebViewPlatform || _controller == null) {
      return Container(
        height: widget.height,
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          gradient: AppGradients.primary,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        alignment: Alignment.centerLeft,
        child: Text(
          widget.fallbackTitle.isNotEmpty
              ? widget.fallbackTitle
              : 'Konten HTML',
          style: texts.titleSmall?.copyWith(
            color: scheme.onPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: WebViewWidget(controller: _controller!),
    );
  }
}
