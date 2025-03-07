import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/server_model.dart';
import '../services/v2ray_service.dart';
import '../services/proxy_service.dart';

class ConnectionProvider with ChangeNotifier {
  bool _isConnected = false;
  ServerModel? _currentServer;
  final String _storageKey = 'current_server';
  bool _autoConnect = false;
  bool _tunMode = false;
  bool get isConnected => _isConnected;
  ServerModel? get currentServer => _currentServer;
  bool get autoConnect => _autoConnect;
  bool get tunMode => _tunMode;
  
  ConnectionProvider() {
    _loadSettings();
    _loadCurrentServer();
  }
  
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _autoConnect = prefs.getBool('auto_connect') ?? false;
    _tunMode = prefs.getBool('tun_mode') ?? false;
    if (_autoConnect) {
      connect();
    }
  }
  
  Future<void> setTunMode(bool value) async {
    if (_isConnected) {
      await disconnect();
    }
    _tunMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tun_mode', value);
    notifyListeners();
    if (_isConnected) {
      await connect();
    }
  }
  
  Future<void> setAutoConnect(bool value) async {
    _autoConnect = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_connect', value);
    notifyListeners();
  }
  
  Future<void> _loadCurrentServer() async {
    final prefs = await SharedPreferences.getInstance();
    final String? serverJson = prefs.getString(_storageKey);
    
    if (serverJson != null) {
      _currentServer = ServerModel.fromJson(Map<String, dynamic>.from(
        Map.castFrom(json.decode(serverJson))
      ));
      notifyListeners();
    }
  }
  
  Future<void> _saveCurrentServer() async {
    final prefs = await SharedPreferences.getInstance();
    if (_currentServer != null) {
      await prefs.setString(_storageKey, json.encode(_currentServer!.toJson()));
    } else {
      await prefs.remove(_storageKey);
    }
  }
  
  Future<void> connect() async {
    if (_currentServer != null) {
      final success = await V2RayService.start(
        serverIp: _currentServer!.ip,
        serverPort: _currentServer!.port,
        tunMode: _tunMode,
      );

      if (success) {
        try {
          // 仅在非TUN模式下启用系统代理
          if (!_tunMode) {
            await ProxyService.enableSystemProxy();
          }
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
    // 仅在非TUN模式下禁用系统代理
    if (!_tunMode) {
      await ProxyService.disableSystemProxy();
    }
    _isConnected = false;
    notifyListeners();
  }
  
  Future<void> setCurrentServer(ServerModel? server) async {
    _currentServer = server;
    await _saveCurrentServer();
    notifyListeners();
  }
}