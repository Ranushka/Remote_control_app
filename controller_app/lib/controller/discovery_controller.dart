import 'dart:async';

import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/foundation.dart';

enum DiscoveryStatus { idle, initializing, scanning, error }

class DiscoveredDevice {
  const DiscoveredDevice({
    required this.id,
    required this.name,
    required this.uri,
    required this.sessionId,
  });

  final String id;
  final String name;
  final Uri uri;
  final String sessionId;
}

class DiscoveryController extends ChangeNotifier {
  DiscoveryController({this.serviceType = '_remotecontrol._tcp'});

  final String serviceType;

  DiscoveryStatus status = DiscoveryStatus.idle;
  String? errorMessage;

  BonsoirDiscovery? _discovery;
  StreamSubscription<BonsoirDiscoveryEvent>? _subscription;
  final Map<String, DiscoveredDevice> _devices = {};

  List<DiscoveredDevice> get devices {
    final values = _devices.values.toList();
    values.sort((a, b) => a.name.compareTo(b.name));
    return values;
  }

  Future<void> start({bool force = false}) async {
    if (!force && (status == DiscoveryStatus.scanning || status == DiscoveryStatus.initializing)) {
      return;
    }
    await stop();
    errorMessage = null;
    _transition(DiscoveryStatus.initializing);

    final discovery = BonsoirDiscovery(type: serviceType);
    _discovery = discovery;

    try {
      await discovery.initialize();
      _subscription = discovery.eventStream?.listen(_handleEvent);
      await discovery.start();
      _transition(DiscoveryStatus.scanning);
    } catch (error) {
      errorMessage = '$error';
      _transition(DiscoveryStatus.error);
    }
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _discovery?.stop();
    } catch (_) {
      // Ignore stop errors.
    }
    _discovery = null;
    final hadDevices = _devices.isNotEmpty;
    _devices.clear();
    final hadError = errorMessage != null;
    errorMessage = null;
    if (status != DiscoveryStatus.idle) {
      _transition(DiscoveryStatus.idle);
    } else if (hadDevices || hadError) {
      notifyListeners();
    }
  }

  Future<void> reScan() => start(force: true);

  void _handleEvent(BonsoirDiscoveryEvent event) {
    switch (event) {
      case BonsoirDiscoveryStartedEvent():
        _transition(DiscoveryStatus.scanning);
        break;
      case BonsoirDiscoveryStoppedEvent():
        _transition(DiscoveryStatus.idle);
        break;
      case BonsoirDiscoveryServiceFoundEvent(service: final service):
        _resolveService(service);
        break;
      case BonsoirDiscoveryServiceResolvedEvent(service: final service):
      case BonsoirDiscoveryServiceUpdatedEvent(service: final service):
        final device = _deviceFromService(service);
        if (device != null) {
          _devices[device.id] = device;
          notifyListeners();
        }
        break;
      case BonsoirDiscoveryServiceLostEvent(service: final service):
        final removed = _devices.remove(_deviceKey(service));
        if (removed != null) {
          notifyListeners();
        }
        break;
      case BonsoirDiscoveryServiceResolveFailedEvent():
        errorMessage = 'Failed to resolve a service.';
        notifyListeners();
        break;
      default:
        break;
    }
  }

  DiscoveredDevice? _deviceFromService(BonsoirService service) {
    final hostFromTxt = service.attributes['host'];
    final host = (hostFromTxt != null && hostFromTxt.isNotEmpty) ? hostFromTxt : service.host;
    if (host == null) {
      return null;
    }
    final protocol = service.attributes['protocol'] ?? 'ws';
    final sessionId = service.attributes['sessionId'] ?? '';
    final uri = Uri(scheme: protocol, host: host, port: service.port);
    return DiscoveredDevice(
      id: _deviceKey(service),
      name: service.name,
      uri: uri,
      sessionId: sessionId,
    );
  }

  Future<void> _resolveService(BonsoirService service) async {
    final resolver = _discovery?.serviceResolver;
    if (resolver == null) {
      return;
    }
    try {
      await resolver.resolveService(service);
    } catch (error) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Failed to resolve service ${service.name}: $error');
      }
    }
  }

  String _deviceKey(BonsoirService service) => '${service.name}:${service.port}';

  void _transition(DiscoveryStatus next) {
    status = next;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(stop());
    super.dispose();
  }
}
