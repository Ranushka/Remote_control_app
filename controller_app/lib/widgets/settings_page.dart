import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class SettingsPage extends HookWidget {
  const SettingsPage({
    super.key,
    required this.sensitivity,
    required this.onSensitivityChanged,
  });

  final double sensitivity;
  final ValueChanged<double> onSensitivityChanged;

  @override
  Widget build(BuildContext context) {
    final local = useState(sensitivity);

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
              'Pointer sensitivity: ${local.value.toStringAsFixed(1)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Slider(
              min: 0.4,
              max: 10.0,
              divisions: 96,
              value: local.value.clamp(0.4, 10.0),
              onChanged: (v) {
                local.value = v;
                onSensitivityChanged(v);
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Use this to control how fast the pointer moves when you drag the touchpad.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
