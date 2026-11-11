import 'dart:async';

import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Animasi masuk bertahap untuk item daftar.
///
/// Item muncul satu per satu (delay kecil berdasarkan [index]) agar daftar
/// terasa hidup tanpa memperlambat petugas. Durasi dan kurva mengikuti
/// token animasi aplikasi.
class StaggeredItem extends StatefulWidget {
  const StaggeredItem({
    super.key,
    required this.index,
    required this.child,
    this.step = const Duration(milliseconds: 35),
    this.maxDelay = const Duration(milliseconds: 245),
  });

  final int index;
  final Widget child;
  final Duration step;
  final Duration maxDelay;

  @override
  State<StaggeredItem> createState() => _StaggeredItemState();
}

class _StaggeredItemState extends State<StaggeredItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppDurations.normal,
  );
  late final Animation<double> _opacity = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.045),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    final delayMs = (widget.index * widget.step.inMilliseconds)
        .clamp(0, widget.maxDelay.inMilliseconds)
        .toInt();
    _delayTimer = Timer(Duration(milliseconds: delayMs), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
