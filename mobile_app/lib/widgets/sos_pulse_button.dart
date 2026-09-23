import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';

class SosPulseButton extends StatefulWidget {
  final VoidCallback onTrigger;
  final bool isTriggering;

  const SosPulseButton({
    Key? key,
    required this.onTrigger,
    this.isTriggering = false,
  }) : super(key: key);

  @override
  State<SosPulseButton> createState() => _SosPulseButtonState();
}

class _SosPulseButtonState extends State<SosPulseButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _countdownTimer;
  int _countdown = 3;
  bool _isHolding = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startHolding() {
    HapticFeedback.heavyImpact();
    setState(() {
      _isHolding = true;
      _countdown = 3;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 1) {
        HapticFeedback.mediumImpact();
        setState(() {
          _countdown--;
        });
      } else {
        // Trigger SOS!
        timer.cancel();
        setState(() {
          _isHolding = false;
        });
        HapticFeedback.vibrate();
        widget.onTrigger();
      }
    });
  }

  void _cancelHolding() {
    _countdownTimer?.cancel();
    if (_isHolding) {
      setState(() {
        _isHolding = false;
        _countdown = 3;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _startHolding(),
      onTapUp: (_) => _cancelHolding(),
      onTapCancel: () => _cancelHolding(),
      onDoubleTap: () {
        // Quick double-tap triggers SOS immediately
        HapticFeedback.vibrate();
        widget.onTrigger();
      },
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          final scale = _isHolding ? 1.05 : _pulseAnimation.value;

          return Stack(
            alignment: Alignment.center,
            children: [
              // Outer Radiating Glow Ripple 1
              Container(
                width: 240 * scale,
                height: 240 * scale,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryRed.withOpacity(0.08),
                ),
              ),

              // Outer Radiating Glow Ripple 2
              Container(
                width: 200 * scale,
                height: 200 * scale,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryRed.withOpacity(0.18),
                ),
              ),

              // Main Mega SOS Button Circle
              Container(
                width: 165,
                height: 165,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppTheme.redPulseGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryRed.withOpacity(0.5),
                      blurRadius: 30,
                      spreadRadius: 4,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: widget.isTriggering
                      ? const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 4,
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.emergency_share,
                              size: 44,
                              color: Colors.white,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _isHolding ? '$_countdown' : 'SOS',
                              style: TextStyle(
                                fontSize: _isHolding ? 36 : 28,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 2,
                              ),
                            ),
                            if (!_isHolding)
                              const Text(
                                'PRESS & HOLD',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white70,
                                  letterSpacing: 1.2,
                                ),
                              ),
                          ],
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
