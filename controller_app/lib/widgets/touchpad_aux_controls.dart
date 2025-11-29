import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_joystick/flutter_joystick.dart';

import 'touchpad_types.dart';

class TouchpadAuxControls extends StatelessWidget {
  const TouchpadAuxControls({
    super.key,
    required this.onPointerDelta,
    required this.onScroll,
    required this.sensitivity,
  });

  final OffsetCallback onPointerDelta;
  final OffsetCallback onScroll;
  final double sensitivity;

  void _triggerScroll(double direction) => onScroll(Offset(0, direction * kScrollButtonDelta));

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : 360;
        double joystickSize = availableWidth * 0.6;
        joystickSize = joystickSize.clamp(180.0, 320.0);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const SizedBox(width: 48),
                  _JoystickControl(
                    onPointerDelta: onPointerDelta,
                    sensitivity: sensitivity,
                    size: joystickSize,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ScrollFab(
                  icon: Icons.keyboard_arrow_up,
                  onPressed: () => _triggerScroll(1),
                ),
                const SizedBox(height: 12),
                _ScrollFab(
                  icon: Icons.keyboard_arrow_down,
                  onPressed: () => _triggerScroll(-1),
                ),
              ],
            ),
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

class _JoystickControl extends StatelessWidget {
  const _JoystickControl({
    required this.onPointerDelta,
    required this.sensitivity,
    required this.size,
  });

  final OffsetCallback onPointerDelta;
  final double sensitivity;
  final double size;

  void _handleStick(StickDragDetails details) {
    final scale = size / 200;
    final offset = Offset(details.x, details.y) * (kJoystickPointerDelta * scale);
    if (offset == Offset.zero) {
      return;
    }
    onPointerDelta(offset * sensitivity);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: Joystick(
        mode: JoystickMode.horizontalAndVertical,
        period: const Duration(milliseconds: 80),
        listener: _handleStick,
        includeInitialAnimation: false,
        stick: JoystickStick(
          size: size * 0.35,
          decoration: JoystickStickDecoration(color: colorScheme.primary),
        ),
        base: JoystickBase(
          size: size,
          mode: JoystickMode.horizontalAndVertical,
          arrowsDecoration: JoystickArrowsDecoration(
            color: Colors.grey,
            enableAnimation: false,
          ),
          decoration: JoystickBaseDecoration(
            drawOuterCircle: false,
            drawInnerCircle: false,
            drawMiddleCircle: true,
            color: colorScheme.surfaceVariant,
            middleCircleColor: colorScheme.primary.withOpacity(0.15),
          ),
        ),
      ),
    );
  }
}
