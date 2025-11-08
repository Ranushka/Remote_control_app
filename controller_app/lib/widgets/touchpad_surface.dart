import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

typedef OffsetCallback = void Function(Offset value);
typedef VoidCallback = void Function();

enum TouchpadMode { pointer, scroll }

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
    final mode = useState(TouchpadMode.pointer);

    // Use scale gesture recognizer only. Scale is a superset of pan on
    // modern Flutter channels, so having both pan and scale causes an
    // assertion. We handle single-finger movement as a scale update with
    // pointerCount == 1, and two-finger movement as scroll (pointerCount >= 2).
    return GestureDetector(
      onTap: onTap,
      onSecondaryTap: onSecondaryTap,
      onLongPress: onSecondaryTap,
      onScaleStart: (_) => mode.value = TouchpadMode.pointer,
      onScaleUpdate: (details) {
        final count = details.pointerCount;
        if (count <= 1) {
          // Single-finger -> pointer movement. Use focalPointDelta which is
          // the gesture's movement delta.
          onPointerDelta(details.focalPointDelta * sensitivity);
        } else {
          // Two+ fingers -> scroll. Invert focalPointDelta to match
          // existing sign convention in the host.
          onScroll(details.focalPointDelta * -1);
        }
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text(
            'Use single-finger drags to move the cursor.\nTwo-finger drag to scroll. Tap for left click, long-press for right click.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
