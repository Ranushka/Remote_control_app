import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'controller/connection_controller.dart';
import 'widgets/touchpad_surface.dart';
import 'widgets/settings_page.dart';

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
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => SettingsPage(
                  sensitivity: sensitivity.value,
                  onSensitivityChanged: (v) => sensitivity.value = v,
                ),
              ));
            },
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
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
                Row(
                  children: [
                    Expanded(
                      child: _StatusBanner(
                        label: statusLabel,
                        controllerStatus: connectionController.status,
                        errorMessage: connectionController.errorMessage,
                      ),
                    ),
                    const SizedBox(width: 8),
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
                _QuickActions(
                  connectionController: connectionController,
                  context: context,
                ),
                const SizedBox(height: 16),
                // Pointer sensitivity moved to Settings page.
                const SizedBox.shrink(),
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
  const _QuickActions({
    required this.connectionController,
    required this.context,
  });

  final ConnectionController connectionController;
  final BuildContext context;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        // Group A: Left and Right Navigation
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  onPressed: () => connectionController.sendKey('left'),
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Left',
                ),
              ),
              SizedBox(
                width: 36,
                height: 36,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  onPressed: () => connectionController.sendKey('right'),
                  icon: const Icon(Icons.arrow_forward),
                  tooltip: 'Right',
                ),
              ),
            ],
          ),
        ),
        // Group B: Previous and Next
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  onPressed: () => connectionController.sendEvent({'type': 'command', 'command': 'media.previous'}),
                  icon: const Icon(Icons.skip_previous),
                  tooltip: 'Previous',
                ),
              ),
              SizedBox(
                width: 36,
                height: 36,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  onPressed: () => connectionController.sendEvent({'type': 'command', 'command': 'media.next'}),
                  icon: const Icon(Icons.skip_next),
                  tooltip: 'Next',
                ),
              ),
            ],
          ),
        ),
        // Group C: Volume
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  onPressed: () => connectionController.sendEvent({'type': 'command', 'command': 'volume.down'}),
                  icon: const Icon(Icons.volume_down),
                  tooltip: 'Vol -',
                ),
              ),
              SizedBox(
                width: 36,
                height: 36,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  onPressed: () => connectionController.sendEvent({'type': 'command', 'command': 'volume.up'}),
                  icon: const Icon(Icons.volume_up),
                  tooltip: 'Vol +',
                ),
              ),
            ],
          ),
        ),
        // Group D: Keyboard
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(4),
          child: SizedBox(
            width: 36,
            height: 36,
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: 18,
              onPressed: () => _showKeyboardDialog(context),
              icon: const Icon(Icons.keyboard),
              tooltip: 'Keyboard',
            ),
          ),
        ),
      ],
    );
  }

  void _showKeyboardDialog(BuildContext context) {
    final textController = TextEditingController();
    final focusNode = FocusNode();

    String previousText = '';
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) {
        return Opacity(
          opacity: 0.0,
          child: AlertDialog(
            content: TextField(
              controller: textController,
              focusNode: focusNode,
              decoration: const InputDecoration(
                hintText: 'Type here...',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              showCursor: false,
              cursorColor: Colors.transparent,
              style: const TextStyle(color: Colors.transparent),
              keyboardType: TextInputType.text,
              onChanged: (value) {
                if (value.length < previousText.length) {
                  // Backspace detected
                  connectionController.sendKey('backspace');
                } else if (value.length > previousText.length) {
                  // New character(s) detected
                  final last = value.substring(previousText.length);
                  for (final ch in last.split('')) {
                    connectionController.sendText(ch);
                  }
                }
                previousText = value;
              },
            ),
          ),
        );
      },
    );
  }
}
