import 'package:flutter/material.dart';

import '../controller/connection_controller.dart';

class QuickActions extends StatelessWidget {
  const QuickActions({
    super.key,
    required this.connectionController,
  });

  final ConnectionController connectionController;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        _ActionGroup(
          children: [
            _actionButton(
              icon: Icons.arrow_back,
              tooltip: 'Left',
              onPressed: () => connectionController.sendKey('left'),
            ),
            _actionButton(
              icon: Icons.arrow_forward,
              tooltip: 'Right',
              onPressed: () => connectionController.sendKey('right'),
            ),
          ],
        ),
        // _ActionGroup(
        //   children: [
        //     _actionButton(
        //       icon: Icons.skip_previous,
        //       tooltip: 'Previous',
        //       onPressed: () => connectionController.sendEvent({'type': 'command', 'command': 'media.previous'}),
        //     ),
        //     _actionButton(
        //       icon: Icons.skip_next,
        //       tooltip: 'Next',
        //       onPressed: () => connectionController.sendEvent({'type': 'command', 'command': 'media.next'}),
        //     ),
        //   ],
        // ),
        _ActionGroup(
          children: [
            _actionButton(
              icon: Icons.volume_down,
              tooltip: 'Vol -',
              onPressed: () => connectionController.sendEvent({'type': 'command', 'command': 'volume.down'}),
            ),
            _actionButton(
              icon: Icons.volume_up,
              tooltip: 'Vol +',
              onPressed: () => connectionController.sendEvent({'type': 'command', 'command': 'volume.up'}),
            ),
          ],
        ),
        _ActionGroup(
          children: [
            _actionButton(
              icon: Icons.fullscreen_exit,
              tooltip: 'Escape',
              onPressed: () => connectionController.sendKey('escape'),
            ),
            _actionButton(
              icon: Icons.keyboard_return,
              tooltip: 'Enter',
              onPressed: () => connectionController.sendKey('enter'),
            ),
          ],
        ),
        _ActionGroup(
          children: [
            _actionButton(
              icon: Icons.keyboard,
              tooltip: 'Keyboard',
              onPressed: () => _showKeyboardDialog(context),
            ),
          ],
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 18,
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon),
      ),
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
                  connectionController.sendKey('backspace');
                } else if (value.length > previousText.length) {
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

class _ActionGroup extends StatelessWidget {
  const _ActionGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}
