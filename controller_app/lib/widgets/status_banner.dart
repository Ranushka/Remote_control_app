import 'package:flutter/material.dart';

import '../controller/connection_controller.dart';

class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
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

  void _showErrorDetails(BuildContext context) {
    if (errorMessage == null || controllerStatus != ControllerStatus.error) {
      return;
    }
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connection error'),
        content: Text(errorMessage!),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final foreground = _foreground(context);
    return GestureDetector(
      onLongPress: () => _showErrorDetails(context),
      child: Container(
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
                  ?.copyWith(color: foreground, fontWeight: FontWeight.bold),
            ),
            if (errorMessage != null && controllerStatus == ControllerStatus.error)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  errorMessage!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: foreground.withOpacity(0.9)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
