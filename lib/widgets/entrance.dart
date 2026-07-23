import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Einmalige Erscheinen-Animation (Fade + sanfter Rise) mit optionalem
/// Stagger-Delay pro Listen-/Grid-Index — das „Lebendig-Werden" von Cards
/// beim ersten Aufbau eines Screens, wie man es von Linear/Stripe kennt.
///
/// - Animiert NUR beim ersten Mount (kein Re-Trigger bei setState/Scroll).
/// - Respektiert `MediaQuery.disableAnimations` (Accessibility / Reduce
///   Motion): dann erscheint der Inhalt sofort.
/// - Stagger ist bei Index 12 gedeckelt, damit lange Listen nicht träge
///   nachtropfen.
class Entrance extends StatefulWidget {
  final Widget child;

  /// Position in Grid/Liste — bestimmt den Stagger-Delay (index × 35 ms).
  final int index;

  const Entrance({super.key, required this.child, this.index = 0});

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      return;
    }
    final delayMs = math.min(widget.index, 12) * 35;
    if (delayMs == 0) {
      _controller.forward();
    } else {
      Future.delayed(Duration(milliseconds: delayMs), () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.05),
          end: Offset.zero,
        ).animate(_curve),
        child: widget.child,
      ),
    );
  }
}
