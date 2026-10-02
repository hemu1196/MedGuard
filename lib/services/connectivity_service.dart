import 'dart:async';

enum ConnectivityStatus { online, offline }

class ConnectivityService {
  final _controller = StreamController<ConnectivityStatus>.broadcast();
  ConnectivityStatus _currentStatus = ConnectivityStatus.online;

  ConnectivityStatus get currentStatus => _currentStatus;
  Stream<ConnectivityStatus> get onConnectivityChanged => _controller.stream;

  void setOffline(bool isOffline) {
    _currentStatus = isOffline
        ? ConnectivityStatus.offline
        : ConnectivityStatus.online;
    _controller.add(_currentStatus);
  }
}
