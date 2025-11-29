import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'touchpad_types.dart';

class TouchpadSurface extends HookWidget {
  const TouchpadSurface({
    super.key,
    required this.onPointerDelta,
    required this.onTap,
    required this.onSecondaryTap,
    required this.onScroll,
    this.sensitivity = 1.0,
  });

  final OffsetCallback onPointerDelta;
  final VoidCallback onTap;
  final VoidCallback onSecondaryTap;
  final OffsetCallback onScroll;
  final double sensitivity;

  @override
  Widget build(BuildContext context) {
    void triggerScroll(double direction) => onScroll(Offset(0, direction * kScrollButtonDelta));
    final gestureScrollTimer = useRef<Timer?>(null);
    final gestureScrollDirection = useState<int?>(null);

    void stopGestureScroll() {
      gestureScrollTimer.value?.cancel();
      gestureScrollTimer.value = null;
      gestureScrollDirection.value = null;
    }

    void startGestureScroll(int direction) {
      if (gestureScrollDirection.value == direction && gestureScrollTimer.value != null) {
        return;
      }
      stopGestureScroll();
      gestureScrollDirection.value = direction;
      triggerScroll(direction.toDouble());
      gestureScrollTimer.value = Timer.periodic(
        const Duration(milliseconds: 140),
        (_) => triggerScroll(direction.toDouble()),
      );
    }

    useEffect(() {
      return () {
        stopGestureScroll();
      };
    }, const []);

    // Use scale gesture recognizer only since it is a superset of pan on modern
    // Flutter channels. We only react to single-finger movement for pointer control.
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      onSecondaryTap: () {
        HapticFeedback.mediumImpact();
        onSecondaryTap();
      },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        onSecondaryTap();
      },
      onScaleStart: (_) => stopGestureScroll(),
      onScaleUpdate: (details) {
        if (details.pointerCount <= 1) {
          stopGestureScroll();
          // Single-finger -> pointer movement. Use focalPointDelta which is
          // the gesture's movement delta.
          onPointerDelta(details.focalPointDelta * sensitivity);
        } else {
          final dy = details.focalPointDelta.dy;
          const double threshold = 2;
          if (dy.abs() > threshold) {
            startGestureScroll(dy < 0 ? 1 : -1);
          }
        }
      },
      onScaleEnd: (_) => stopGestureScroll(),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'Use single-finger drags to move the cursor.\nTap for left click, long-press for right click.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
