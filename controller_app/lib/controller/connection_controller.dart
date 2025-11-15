import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';

enum ControllerStatus { disconnected, connecting, connected, error }

class ConnectionDetails {
  ConnectionDetails({required this.url, required this.sessionId});

  factory ConnectionDetails.fromQrPayload(String payload) {
    final decoded = jsonDecode(payload) as Map<String, dynamic>;
    final protocol = decoded['protocol'] as String? ?? 'ws';
    final host = decoded['host'] as String?;
    final port = decoded['port'];
    final sessionId = decoded['sessionId'] as String? ?? '';
    if (host == null || port == null) {
      throw const FormatException('Missing host or port in QR payload');
    }
    final uri = Uri(scheme: protocol, host: host, port: port as int);
    return ConnectionDetails(url: uri, sessionId: sessionId);
  }

  final Uri url;
  final String sessionId;
}

class ConnectionController extends ChangeNotifier {
  ControllerStatus status = ControllerStatus.disconnected;
  String? errorMessage;
  ConnectionDetails? _details;
  IOWebSocketChannel? _channel;
  Timer? _heartbeatTimer;

  StreamSubscription? _channelSub;

  void connect(ConnectionDetails details) {
    _details = details;
    _transition(ControllerStatus.connecting);
    _connectInternal(details);
  }

  Future<void> _connectInternal(ConnectionDetails details) async {
    await disconnect();
    try {
      final socket = await WebSocket.connect(details.url.toString());
      _channel = IOWebSocketChannel(socket);
      _channelSub = _channel!.stream.listen(
        _handleMessage,
        onDone: _handleDone,
        onError: _handleError,
      );
      _transition(ControllerStatus.connected);
      _startHeartbeat();
    } catch (error) {
      errorMessage = 'Failed to connect: $error';
      _transition(ControllerStatus.error);
    }
  }

  void _handleMessage(dynamic message) {
    if (kDebugMode) {
      debugPrint('Host -> Controller: $message');
    }
  }

  void _handleDone() {
    _stopHeartbeat();
    _transition(ControllerStatus.disconnected);
  }

  void _handleError(Object error) {
    errorMessage = '$error';
    _stopHeartbeat();
    _transition(ControllerStatus.error);
  }

  void sendEvent(Map<String, dynamic> event) {
    if (_channel == null) {
      return;
    }
    try {
      _channel!.sink.add(jsonEncode(event));
    } catch (error) {
      errorMessage = 'Failed to send event: $error';
      notifyListeners();
    }
  }

  void sendMouseDelta(Offset delta) {
    sendEvent({'type': 'mouse_move', 'deltaX': delta.dx, 'deltaY': delta.dy});
  }

  void sendTap({String button = 'left'}) {
    sendEvent({'type': 'mouse_click', 'button': button, 'double': false});
  }

  void sendScroll(Offset delta) {
    sendEvent({'type': 'mouse_scroll', 'scrollX': delta.dx, 'scrollY': delta.dy});
  }

  void sendKey(String key, {List<String> modifiers = const []}) {
    sendEvent({'type': 'key_press', 'key': key, 'action': 'tap', 'modifiers': modifiers});
  }

  void sendText(String text) {
    sendEvent({'type': 'text_input', 'text': text});
  }

  Future<void> disconnect() async {
    _stopHeartbeat();
    await _channelSub?.cancel();
    _channelSub = null;
    await _channel?.sink.close();
    _channel = null;
    if (status != ControllerStatus.disconnected) {
      _transition(ControllerStatus.disconnected);
    }
  }

  void retry() {
    final details = _details;
    if (details != null) {
      connect(details);
    }
  }

  void _transition(ControllerStatus next) {
    status = next;
    notifyListeners();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      sendEvent({'type': 'heartbeat'});
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  @override
  void dispose() {
    _stopHeartbeat();
    _channelSub?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}
