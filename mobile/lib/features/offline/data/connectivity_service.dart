import 'package:connectivity_plus/connectivity_plus.dart';

enum MobileConnectivityState { online, offline }

abstract class ConnectivityService {
  Future<MobileConnectivityState> current();
  Stream<MobileConnectivityState> watch();
}

class DeviceConnectivityService implements ConnectivityService {
  DeviceConnectivityService({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<MobileConnectivityState> current() async {
    try {
      return _map(await _connectivity.checkConnectivity());
    } catch (_) {
      return MobileConnectivityState.offline;
    }
  }

  @override
  Stream<MobileConnectivityState> watch() async* {
    var previous = await current();
    yield previous;
    try {
      await for (final results in _connectivity.onConnectivityChanged) {
        final next = _map(results);
        if (next == previous) continue;
        previous = next;
        yield next;
      }
    } catch (_) {
      if (previous != MobileConnectivityState.offline) {
        yield MobileConnectivityState.offline;
      }
    }
  }
}

MobileConnectivityState _map(List<ConnectivityResult> results) {
  return results.isEmpty ||
          results.every((item) => item == ConnectivityResult.none)
      ? MobileConnectivityState.offline
      : MobileConnectivityState.online;
}
