import 'package:flutter/material.dart';

enum ButtonState { idle, loading, success }

class RequestHelpButton extends StatefulWidget {
  final Future<void> Function() onRequest;

  const RequestHelpButton({super.key, required this.onRequest});

  @override
  State<RequestHelpButton> createState() => _RequestHelpButtonState();
}

class _RequestHelpButtonState extends State<RequestHelpButton>
    with TickerProviderStateMixin {
  ButtonState _state = ButtonState.idle;

  // Pulse animation for idle glow
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Tap bounce values
  double _scale = 1.0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (_state != ButtonState.idle) return;

    setState(() => _state = ButtonState.loading);

    try {
      await widget.onRequest();
      
      if (!mounted) return;
      setState(() => _state = ButtonState.success);

      // Show success for 2 seconds then reset
      await Future.delayed(const Duration(milliseconds: 2000));
      if (mounted) {
        setState(() => _state = ButtonState.idle);
      }
    } catch (_) {
      // If error, just go back to idle
      if (mounted) {
        setState(() => _state = ButtonState.idle);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dimensions based on state
    final isIdle = _state == ButtonState.idle;

    // Morph sizes: Rectangle when idle, Circle when loading/success
    final targetWidth = isIdle ? MediaQuery.of(context).size.width * 0.8 : 64.0;
    final targetHeight = 64.0; 

    // Colors
    Color targetColor = Colors.red;
    if (_state == ButtonState.loading) targetColor = Colors.orange;
    if (_state == ButtonState.success) targetColor = Colors.green;

    return Center(
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          // Pulse opacity scales when idle
          final pulseOpacity = isIdle ? _pulseAnimation.value * 0.5 : 0.0;
          return AnimatedScale(
            scale: _scale,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutBack,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer Glow / Pulse
                if (isIdle)
                  Container(
                    width: targetWidth,
                    height: targetHeight,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: pulseOpacity),
                          blurRadius: 25 * _pulseAnimation.value,
                          spreadRadius: 10 * _pulseAnimation.value,
                        ),
                      ],
                    ),
                  ),

                // Main Button Container
                AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOutCubic,
                  width: targetWidth,
                  height: targetHeight,
                  decoration: BoxDecoration(
                    color: targetColor,
                    borderRadius: BorderRadius.circular(32), // Morph shape organically
                    boxShadow: [
                      if (!isIdle) // Idle shadow handled by pulse
                        BoxShadow(
                          color: targetColor.withValues(alpha: 0.3),
                          blurRadius: 15,
                          spreadRadius: 2,
                          offset: const Offset(0, 5),
                        )
                    ],
                  ),
                  clipBehavior: Clip.antiAlias, // Important for ripple
                  child: Material(
                    color: Colors.transparent,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Inkwell Ripple
                        if (isIdle)
                          Positioned.fill(
                            child: InkWell(
                              highlightColor: Colors.white.withValues(alpha: 0.1),
                              splashColor: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(32),
                              onTap: _handleTap,
                              onHighlightChanged: (isPressed) {
                                setState(() => _scale = isPressed ? 0.92 : 1.0);
                              },
                            ),
                          ),
                          
                        // Button Content (Animated Switcher handles fades)
                        IgnorePointer(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            transitionBuilder: (child, animation) => FadeTransition(
                              opacity: animation,
                              child: ScaleTransition(scale: animation, child: child),
                            ),
                            child: _buildContent(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent() {
    switch (_state) {
      case ButtonState.idle:
        return const Row(
          key: ValueKey('idle'),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
            SizedBox(width: 8),
            Text(
              "REQUEST HELP",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
                letterSpacing: 1.2,
              ),
            ),
          ],
        );
      case ButtonState.loading:
        return const SizedBox(
          key: ValueKey('loading'),
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2.5,
          ),
        );
      case ButtonState.success:
        return const Icon(
          Icons.check_rounded,
          key: ValueKey('success'),
          color: Colors.white,
          size: 32,
        );
    }
  }
}
