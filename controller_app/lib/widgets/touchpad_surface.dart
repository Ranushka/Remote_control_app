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

    return GestureDetector(
      onTap: onTap,
      onSecondaryTap: onSecondaryTap,
      onLongPress: onSecondaryTap,
      onPanStart: (_) => mode.value = TouchpadMode.pointer,
      onPanUpdate: (details) {
        if (mode.value == TouchpadMode.pointer) {
          onPointerDelta(details.delta * sensitivity);
        }
      },
      onScaleStart: (_) => mode.value = TouchpadMode.scroll,
      onScaleUpdate: (details) {
        if (details.pointerCount >= 2) {
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
