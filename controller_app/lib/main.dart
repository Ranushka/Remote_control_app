import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'controller/connection_controller.dart';
import 'controller/discovery_controller.dart';
import 'widgets/touchpad_surface.dart';
import 'widgets/settings_page.dart';
import 'widgets/status_banner.dart';
import 'widgets/quick_actions.dart';
import 'widgets/discovery_overlay.dart';
import 'widgets/qr_scanner_overlay.dart';

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
    final discoveryController = useMemoized(DiscoveryController.new);
    useEffect(() => discoveryController.dispose, [discoveryController]);
    useListenable(discoveryController);

    final showScanner = useState(false);
    final showDiscovery = useState(false);
    final sensitivity = useState(1.0);
    final auxControlsEnabled = useState(true);

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

    useEffect(() {
      if (showDiscovery.value) {
        discoveryController.start();
      } else {
        discoveryController.stop();
      }
      return null;
    }, [showDiscovery.value, discoveryController]);

    final statusLabel = switch (connectionController.status) {
      ControllerStatus.disconnected => 'Disconnected',
      ControllerStatus.connecting => 'Connecting…',
      ControllerStatus.connected => 'Connected',
      ControllerStatus.error => 'Error',
    };
    final escapeTopOffset = MediaQuery.of(context).size.height * 0.14;

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: StatusBanner(
                          label: statusLabel,
                          controllerStatus: connectionController.status,
                          errorMessage: connectionController.errorMessage,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          showScanner.value = false;
                          showDiscovery.value = true;
                        },
                        icon: const Icon(Icons.wifi_tethering),
                        tooltip: 'Find Hosts',
                      ),
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
                      IconButton(
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => SettingsPage(
                              sensitivity: sensitivity.value,
                              onSensitivityChanged: (v) => sensitivity.value = v,
                              auxControlsEnabled: auxControlsEnabled.value,
                              onAuxControlsChanged: (value) => auxControlsEnabled.value = value,
                            ),
                          ));
                        },
                        icon: const Icon(Icons.settings),
                        tooltip: 'Settings',
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
                  const SizedBox(height: 12),
                  if (auxControlsEnabled.value) ...[
                    // const SizedBox(height: 12),
                    TouchpadAuxControls(
                      sensitivity: sensitivity.value,
                      onPointerDelta: connectionController.sendMouseDelta,
                      onScroll: connectionController.sendScroll,
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  QuickActions(connectionController: connectionController),
                  // const SizedBox(height: 16),
                  // Pointer sensitivity moved to Settings page.
                  const SizedBox.shrink(),
                ],
              ),
            ),
          ),
          if (showScanner.value) QrScannerOverlay(onDetect: handleQr, onClose: () => showScanner.value = false),
          if (showDiscovery.value)
            DiscoveryOverlay(
              controller: discoveryController,
              onSelect: (device) {
                connectionController.connect(ConnectionDetails(url: device.uri, sessionId: device.sessionId));
                showDiscovery.value = false;
              },
              onClose: () => showDiscovery.value = false,
            ),
        ],
      ),
    );
  }
}
