import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Tactical Floating Action Button — design system "Glass & Gradient" rule.
/// Uses glassmorphism (20px blur on primary tint @60%) with pulsing glow
/// that signals urgency for the emergency trigger.
class GlassFab extends StatefulWidget {
  const GlassFab({
    super.key,
    required this.onPressed,
    required this.icon,
    this.label,
    this.size = 64,
    this.pulse = true,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String? label;
  final double size;
  final bool pulse;

  @override
  State<GlassFab> createState() => _GlassFabState();
}

class _GlassFabState extends State<GlassFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.pulse) _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final glow = widget.pulse ? 0.3 + _controller.value * 0.4 : 0.4;
        return Stack(
          alignment: Alignment.center,
          children: [
            // Pulse glow
            Container(
              width: widget.size * 1.6,
              height: widget.size * 1.6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(glow),
                    blurRadius: 40,
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),
            // Glass + gradient circle
            ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.primaryGradient,
                  ),
                  child: Icon(
                    widget.icon,
                    color: AppColors.onPrimary,
                    size: widget.size * 0.42,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    return Semantics(
      button: true,
      label: widget.label ?? 'Acil eylem',
      child: InkResponse(
        onTap: widget.onPressed,
        radius: widget.size,
        child: content,
      ),
    );
  }
}
