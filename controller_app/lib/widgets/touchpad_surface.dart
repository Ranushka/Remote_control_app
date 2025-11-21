import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

typedef OffsetCallback = void Function(Offset value);
typedef VoidCallback = void Function();

const double _kScrollButtonDelta = 120;

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
    void triggerScroll(double direction) => onScroll(Offset(0, direction * _kScrollButtonDelta));

    // Use scale gesture recognizer only since it is a superset of pan on modern
    // Flutter channels. We only react to single-finger movement for pointer control.
    return LayoutBuilder(
      builder: (context, constraints) {
        final bottomOffset = constraints.maxHeight.isFinite ? constraints.maxHeight * 0.2 : 32.0;
        return Stack(
          children: [
            GestureDetector(
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
              onScaleUpdate: (details) {
                if (details.pointerCount <= 1) {
                  // Single-finger -> pointer movement. Use focalPointDelta which is
                  // the gesture's movement delta.
                  onPointerDelta(details.focalPointDelta * sensitivity);
                }
              },
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
            ),
            Positioned(
              right: 16,
              bottom: bottomOffset,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ScrollFab(
                    icon: Icons.keyboard_arrow_up,
                    onPressed: () => triggerScroll(1),
                  ),
                  const SizedBox(height: 4),
                  _ScrollFab(
                    icon: Icons.keyboard_arrow_down,
                    onPressed: () => triggerScroll(-1),
                  ),
                ],
              ),
            )
          ],
        );
      },
    );
  }
}

class _ScrollFab extends HookWidget {
  const _ScrollFab({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final timerRef = useRef<Timer?>(null);
    final isHolding = useState(false);

    void cancelTimer() {
      timerRef.value?.cancel();
      timerRef.value = null;
    }

    useEffect(() => cancelTimer, const []);

    void triggerWithHaptics() {
      HapticFeedback.selectionClick();
      onPressed();
    }

    void startAutoScroll() {
      if (isHolding.value) return;
      isHolding.value = true;
      triggerWithHaptics();
      cancelTimer();
      timerRef.value = Timer.periodic(const Duration(milliseconds: 120), (_) => triggerWithHaptics());
    }

    void handlePointerUp() {
      cancelTimer();
      isHolding.value = false;
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => startAutoScroll(),
      onPointerUp: (_) => handlePointerUp(),
      onPointerCancel: (_) => handlePointerUp(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: colorScheme.onPrimaryContainer,
          size: 32,
        ),
      ),
    );
  }
}
