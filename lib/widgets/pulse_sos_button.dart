import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PulseSosButton extends StatefulWidget {
  final VoidCallback onTap;
  final double size;

  const PulseSosButton({
    super.key,
    required this.onTap,
    this.size = 200.0,
  });

  @override
  State<PulseSosButton> createState() => _PulseSosButtonState();
}

class _PulseSosButtonState extends State<PulseSosButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final effectiveSize = (screenWidth * 0.45).clamp(130.0, widget.size);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          final scale = _isPressed ? 0.92 : 1.0;
          final pulseValue = _pulseAnimation.value;

          return Transform.scale(
            scale: scale,
            child: SizedBox(
              width: effectiveSize * 1.25,
              height: effectiveSize * 1.25,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer Glow Ring 2
                  Container(
                    width: effectiveSize * pulseValue * 1.2,
                    height: effectiveSize * pulseValue * 1.2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFF43F5E).withValues(alpha: 0.12),
                    ),
                  ),

                  // Outer Glow Ring 1
                  Container(
                    width: effectiveSize * pulseValue * 1.08,
                    height: effectiveSize * pulseValue * 1.08,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFF43F5E).withValues(alpha: 0.22),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF43F5E).withValues(alpha: 0.3),
                          blurRadius: 25,
                          spreadRadius: 6,
                        ),
                      ],
                    ),
                  ),

                  // Central Main Button Outer Border
                  Container(
                    width: effectiveSize,
                    height: effectiveSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFFB7185),
                          Color(0xFFE11D48),
                          Color(0xFF9F1239),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE11D48).withValues(alpha: 0.5),
                          blurRadius: 24,
                          spreadRadius: 2,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(6.0),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            center: Alignment(-0.3, -0.3),
                            radius: 0.85,
                            colors: [
                              Color(0xFFFDA4AF),
                              Color(0xFFF43F5E),
                              Color(0xFFBE123C),
                            ],
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.6),
                            width: 3.5,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.touch_app_rounded,
                              color: Colors.white,
                              size: 34,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'SOS',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 44.0,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2.0,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              'TAP FOR HELP',
                              style: GoogleFonts.outfit(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 11.0,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
