import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  factory ConnectionDetails.fromStorage(Map<String, dynamic> json) {
    final rawUrl = json['url'] as String?;
    if (rawUrl == null) {
      throw const FormatException('Missing url in stored connection details');
    }
    final uri = Uri.parse(rawUrl);
    final sessionId = json['sessionId'] as String? ?? '';
    return ConnectionDetails(url: uri, sessionId: sessionId);
  }

  Map<String, dynamic> toJson() => {
        'url': url.toString(),
        'sessionId': sessionId,
      };

  final Uri url;
  final String sessionId;
}

class ConnectionController extends ChangeNotifier {
  ConnectionController({LastConnectionStore? lastConnectionStore})
      : _lastConnectionStore = lastConnectionStore ?? const LastConnectionStore();

  ControllerStatus status = ControllerStatus.disconnected;
  String? errorMessage;
  ConnectionDetails? _details;
  IOWebSocketChannel? _channel;
  Timer? _heartbeatTimer;
  final LastConnectionStore _lastConnectionStore;
  Timer? _reconnectTimer;
  StreamSubscription? _channelSub;
  bool _autoConnectAttempted = false;

  Future<void> tryAutoConnect() async {
    if (_autoConnectAttempted) {
      return;
    }
    _autoConnectAttempted = true;
    try {
      final details = await _lastConnectionStore.load();
      if (details != null) {
        connect(details);
      }
    } catch (error) {
      debugPrint('Failed to load last connection: $error');
    }
  }

  void connect(ConnectionDetails details) {
    _details = details;
    _transition(ControllerStatus.connecting);
    _cancelReconnect();
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
      unawaited(_lastConnectionStore.save(details));
    } catch (error) {
      errorMessage = 'Failed to connect: $error';
      _transition(ControllerStatus.error);
      _scheduleReconnect();
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
    _scheduleReconnect();
  }

  void _handleError(Object error) {
    errorMessage = '$error';
    _stopHeartbeat();
    _transition(ControllerStatus.error);
    _scheduleReconnect();
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
    _cancelReconnect();
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

  void _scheduleReconnect() {
    if (_details == null || _reconnectTimer != null) {
      return;
    }
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      _reconnectTimer = null;
      final details = _details;
      if (details != null && status != ControllerStatus.connected) {
        _connectInternal(details);
      }
    });
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  @override
  void dispose() {
    _stopHeartbeat();
    _cancelReconnect();
    _channelSub?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}

class LastConnectionStore {
  const LastConnectionStore();

  static const _prefsKey = 'last_connection_details';

  Future<void> save(ConnectionDetails details) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(details.toJson()));
  }

  Future<ConnectionDetails?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return ConnectionDetails.fromStorage(decoded);
      }
    } catch (_) {
      await prefs.remove(_prefsKey);
    }
    return null;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}
