import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class SettingsPage extends HookWidget {
  const SettingsPage({
    super.key,
    required this.sensitivity,
    required this.onSensitivityChanged,
    required this.auxControlsEnabled,
    required this.onAuxControlsChanged,
  });

  final double sensitivity;
  final ValueChanged<double> onSensitivityChanged;
  final bool auxControlsEnabled;
  final ValueChanged<bool> onAuxControlsChanged;

  @override
  Widget build(BuildContext context) {
    final localSensitivity = useState(sensitivity);
    final localAuxControls = useState(auxControlsEnabled);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pointer sensitivity: ${localSensitivity.value.toStringAsFixed(1)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Slider(
              min: 0.4,
              max: 10.0,
              divisions: 96,
              value: localSensitivity.value.clamp(0.4, 10.0),
              onChanged: (v) {
                localSensitivity.value = v;
                onSensitivityChanged(v);
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Use this to control how fast the pointer moves when you drag the touchpad.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const Divider(height: 32),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show joystick & scroll controls'),
              subtitle: const Text('Display the precision joystick with dedicated scroll buttons.'),
              value: localAuxControls.value,
              onChanged: (value) {
                localAuxControls.value = value;
                onAuxControlsChanged(value);
              },
            ),
          ],
        ),
      ),
    );
  }
}
