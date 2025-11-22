import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_joystick/flutter_joystick.dart';

typedef OffsetCallback = void Function(Offset value);
typedef VoidCallback = void Function();

const double _kScrollButtonDelta = 120;
const double _kJoystickPointerDelta = 45;

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

  void _triggerScroll(double direction) => onScroll(Offset(0, direction * _kScrollButtonDelta));

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      decoration: BoxDecoration(
        // color: colorScheme.surfaceVariant,
        // color: new Color(0x00000000),
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
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
      ),
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
    final offset = Offset(details.x, details.y) * (_kJoystickPointerDelta * scale);
    if (offset == Offset.zero) {
      return;
    }
    onPointerDelta(offset * sensitivity);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      child: SizedBox(
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
      ),
    );
  }
}
