import 'package:flutter/material.dart';

import '../controller/discovery_controller.dart';

class DiscoveryOverlay extends StatelessWidget {
  const DiscoveryOverlay({
    super.key,
    required this.controller,
    required this.onSelect,
    required this.onClose,
  });

  final DiscoveryController controller;
  final ValueChanged<DiscoveredDevice> onSelect;
  final VoidCallback onClose;

  String _statusLabel() {
    return switch (controller.status) {
      DiscoveryStatus.initializing => 'Preparing discovery…',
      DiscoveryStatus.scanning => 'Searching for hosts…',
      DiscoveryStatus.error => 'Discovery error',
      DiscoveryStatus.idle => 'Idle',
    };
  }

  @override
  Widget build(BuildContext context) {
    final devices = controller.devices;
    final isScanning = controller.status == DiscoveryStatus.scanning || controller.status == DiscoveryStatus.initializing;
    return ColoredBox(
      color: Colors.black.withOpacity(0.85),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Text(
                    'Available Hosts',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    style: IconButton.styleFrom(backgroundColor: Colors.white10, foregroundColor: Colors.white),
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  if (isScanning) ...[
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    _statusLabel(),
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: controller.reScan,
                    child: const Text('Refresh', style: TextStyle(color: Colors.white)),
                  )
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: devices.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isScanning)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: Text(
                                'Scanning your network…',
                                style: TextStyle(color: Colors.white70),
                              ),
                            )
                          else
                            const Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: Text(
                                'No hosts found yet.',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                          if (!isScanning)
                            const Text(
                              'Ensure the host is running on the same network.',
                              style: TextStyle(color: Colors.white54),
                            ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: devices.length,
                      itemBuilder: (context, index) {
                        final device = devices[index];
                        return Card(
                          color: Colors.white12,
                          child: ListTile(
                            leading: const Icon(Icons.computer, color: Colors.white),
                            title: Text(
                              device.name,
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              '${device.uri.host}:${device.uri.port}\nSession: ${device.sessionId.isEmpty ? 'Unknown' : device.sessionId}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            isThreeLine: true,
                            trailing: const Icon(Icons.chevron_right, color: Colors.white),
                            onTap: () => onSelect(device),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
