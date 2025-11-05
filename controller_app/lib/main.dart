import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'controller/connection_controller.dart';
import 'widgets/touchpad_surface.dart';

void main() {
  runApp(const RemoteControlApp());
}

class RemoteControlApp extends StatelessWidget {
  const RemoteControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Remote Control',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const ControllerHomePage(),
    );
  }
}

class ControllerHomePage extends HookWidget {
  const ControllerHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final connectionController = useMemoized(ConnectionController.new);
    useEffect(() => connectionController.dispose, [connectionController]);
    useListenable(connectionController);

    final showScanner = useState(false);
    final sensitivity = useState(1.0);

    Future<void> handleQr(String? value) async {
      if (value == null) {
        return;
      }
      try {
        final details = ConnectionDetails.fromQrPayload(value);
        connectionController.connect(details);
        showScanner.value = false;
      } on FormatException catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid QR code: ${error.message}')),
        );
      }
    }

    final statusLabel = switch (connectionController.status) {
      ControllerStatus.disconnected => 'Disconnected',
      ControllerStatus.connecting => 'Connecting…',
      ControllerStatus.connected => 'Connected',
      ControllerStatus.error => 'Error',
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Remote Control'),
        actions: [
          IconButton(
            onPressed: () => showScanner.value = true,
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scan QR Code',
          ),
          IconButton(
            onPressed: () => connectionController.retry(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Reconnect',
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StatusBanner(
                  label: statusLabel,
                  controllerStatus: connectionController.status,
                  errorMessage: connectionController.errorMessage,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: TouchpadSurface(
                    sensitivity: sensitivity.value,
                    onPointerDelta: connectionController.sendMouseDelta,
                    onSecondaryTap: () => connectionController.sendTap(button: 'right'),
                    onTap: () => connectionController.sendTap(),
                    onScroll: connectionController.sendScroll,
                  ),
                ),
                const SizedBox(height: 16),
                _QuickActions(connectionController: connectionController),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pointer sensitivity: ${sensitivity.value.toStringAsFixed(1)}',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    Slider(
                      min: 0.4,
                      max: 3.0,
                      value: sensitivity.value,
                      onChanged: (value) => sensitivity.value = value,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (showScanner.value) _QrScannerOverlay(onDetect: handleQr, onClose: () => showScanner.value = false),
        ],
      ),
    );
  }
}

class _QrScannerOverlay extends StatelessWidget {
  const _QrScannerOverlay({required this.onDetect, required this.onClose});

  final ValueChanged<String?> onDetect;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withOpacity(0.8),
      child: SafeArea(
        child: Stack(
          children: [
            MobileScanner(
              onDetect: (capture) {
                final barcode =
                    capture.barcodes.isNotEmpty ? capture.barcodes.first : null;
                if (barcode != null) {
                  onDetect(barcode.rawValue);
                }
              },
            ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                style: IconButton.styleFrom(backgroundColor: Colors.black54, foregroundColor: Colors.white),
                onPressed: onClose,
                icon: const Icon(Icons.close),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.label,
    required this.controllerStatus,
    this.errorMessage,
  });

  final String label;
  final ControllerStatus controllerStatus;
  final String? errorMessage;

  Color _background(BuildContext context) {
    return switch (controllerStatus) {
      ControllerStatus.connected => Colors.green.shade600,
      ControllerStatus.connecting => Colors.orange.shade600,
      ControllerStatus.error => Colors.red.shade700,
      ControllerStatus.disconnected => Theme.of(context).colorScheme.surfaceVariant,
    };
  }

  Color _foreground(BuildContext context) {
    return controllerStatus == ControllerStatus.disconnected
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _background(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: _foreground(context), fontWeight: FontWeight.bold),
          ),
          if (errorMessage != null && controllerStatus == ControllerStatus.error)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                errorMessage!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white),
              ),
            )
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.connectionController});

  final ConnectionController connectionController;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        FilledButton.icon(
          onPressed: () => connectionController.sendKey('enter'),
          icon: const Icon(Icons.keyboard_return),
          label: const Text('Enter'),
        ),
        FilledButton.icon(
          onPressed: () => connectionController.sendKey('escape'),
          icon: const Icon(Icons.close_fullscreen),
          label: const Text('Esc'),
        ),
        FilledButton.icon(
          onPressed: () => connectionController.sendKey('space'),
          icon: const Icon(Icons.space_bar),
          label: const Text('Space'),
        ),
        FilledButton.icon(
          onPressed: () => connectionController.sendEvent({'type': 'command', 'command': 'media.play_pause'}),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Play/Pause'),
        ),
        FilledButton.icon(
          onPressed: () => connectionController.sendEvent({'type': 'command', 'command': 'media.next'}),
          icon: const Icon(Icons.skip_next),
          label: const Text('Next'),
        ),
        FilledButton.icon(
          onPressed: () => connectionController.sendEvent({'type': 'command', 'command': 'media.previous'}),
          icon: const Icon(Icons.skip_previous),
          label: const Text('Previous'),
        ),
        FilledButton.icon(
          onPressed: () => connectionController.sendEvent({'type': 'command', 'command': 'volume.up'}),
          icon: const Icon(Icons.volume_up),
          label: const Text('Vol +'),
        ),
        FilledButton.icon(
          onPressed: () => connectionController.sendEvent({'type': 'command', 'command': 'volume.down'}),
          icon: const Icon(Icons.volume_down),
          label: const Text('Vol -'),
        ),
        FilledButton.icon(
          onPressed: () => connectionController.sendEvent({'type': 'command', 'command': 'volume.mute'}),
          icon: const Icon(Icons.volume_off),
          label: const Text('Mute'),
        ),
        FilledButton.icon(
          onPressed: () => connectionController.sendEvent({'type': 'command', 'command': 'power.sleep'}),
          icon: const Icon(Icons.power_settings_new),
          label: const Text('Sleep'),
        ),
      ],
    );
  }
}
