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
          Container(
            color: Colors.black.withOpacity(0.4),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
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
                        size: 40,
                        color: color ?? const Color(0xFF10447E),
                      )
                      .animate(onPlay: (controller) => controller.repeat())
                      .scale(duration: 1000.ms, begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1), curve: Curves.easeInOut)
                      .then()
                      .scale(duration: 1000.ms, begin: const Offset(1.1, 1.1), end: const Offset(0.9, 0.9), curve: Curves.easeInOut),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .shimmer(duration: 2000.ms, color: Colors.grey.shade300),
                  ],
                ),
              )
              .animate()
              .scale(duration: 300.ms, curve: Curves.easeOutBack)
              .fadeIn(duration: 200.ms),
            ),
          ),
      ],
    );
  }
}
