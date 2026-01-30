import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ProcessingOverlay extends StatelessWidget {
  final bool isLoading;
  final String message;
  final IconData icon;
  final Color? color;
  final Widget child;

  const ProcessingOverlay({
    Key? key,
    required this.isLoading,
    required this.child,
    this.message = 'Procesando...',
    this.icon = Icons.sync,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: Animate(
              effects: [FadeEffect(duration: 200.ms)],
              child: Stack(
                children: [
                  // Glassmorphism Background
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(
                      color: Colors.black.withOpacity(0.3),
                    ),
                  ),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: (color ?? const Color(0xFF10447E)).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              icon,
                              size: 48,
                              color: color ?? const Color(0xFF10447E),
                            )
                            .animate(onPlay: (controller) => controller.repeat())
                            .rotate(duration: 1500.ms, curve: Curves.easeInOut)
                            .shimmer(duration: 1500.ms, color: Colors.white.withOpacity(0.5)),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                              letterSpacing: 0.5,
                            ),
                          ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
                        ],
                      ),
                    ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
