import 'package:flutter/foundation.dart';
import '../models/server_model.dart';
import '../services/v2ray_service.dart';
import '../services/proxy_service.dart';

class ConnectionProvider with ChangeNotifier {
  bool _isConnected = false;
  ServerModel? _currentServer;
  
  bool get isConnected => _isConnected;
  ServerModel? get currentServer => _currentServer;

  Future<void> connect() async {
    if (_currentServer != null) {
      final success = await V2RayService.start(
        serverIp: _currentServer!.ip,
        serverPort: _currentServer!.port,
      );

      if (success) {
        try {
          await ProxyService.enableSystemProxy();
          _isConnected = true;
          notifyListeners();
        } catch (e) {
          await V2RayService.stop();
          rethrow;
        }
      }
    }
  }

  Future<void> disconnect() async {
    await V2RayService.stop();
    await ProxyService.disableSystemProxy();
    _isConnected = false;
    notifyListeners();
  }

  void setCurrentServer(ServerModel? server) {
    _currentServer = server;
    notifyListeners();
  }
} 