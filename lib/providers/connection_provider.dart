import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/server_model.dart';
import '../services/v2ray_service.dart';
import '../services/proxy_service.dart';

class ConnectionProvider with ChangeNotifier {
  bool _isConnected = false;
  bool _isConnecting = false;
  String? _connectionError;
  ServerModel? _currentServer;
  final String _storageKey = 'current_server';
  bool _autoConnect = false;
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String? get connectionError => _connectionError;
  ServerModel? get currentServer => _currentServer;
  bool get autoConnect => _autoConnect;
  
  ConnectionProvider() {
    _loadSettings();
    _loadCurrentServer();
  }
  
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _autoConnect = prefs.getBool('auto_connect') ?? false;
    if (_autoConnect) {
      connect();
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
    if (_currentServer != null && !_isConnecting) {
      _isConnecting = true;
      _connectionError = null;
      notifyListeners();

      try {
        final success = await V2RayService.start(
          serverIp: _currentServer!.ip,
          serverPort: _currentServer!.port,
        );

        if (success) {
          await ProxyService.enableSystemProxy();
          _isConnected = true;
          _isConnecting = false;
          _connectionError = "正在等待网络稳定...";
          notifyListeners();
          
          // 延迟5秒后进行连通性测试
          await Future.delayed(const Duration(seconds: 5));
          final testResult = await testConnection();
          if (!testResult) {
            _connectionError = "连接已建立，但访问受限";
            notifyListeners();
            return;
          }
          _connectionError = null;
        } else {
          _connectionError = "连接失败，请稍后重试";
          _isConnecting = false;
        }
      } catch (e) {
        _connectionError = e.toString();
        await V2RayService.stop();
        await ProxyService.disableSystemProxy();
        _isConnecting = false;
      } finally {
        notifyListeners();
      }
    } else if (_isConnecting) {
      // 如果正在连接中，则取消连接
      _isConnecting = false;
      _connectionError = "已取消连接";
      await V2RayService.stop();
      await ProxyService.disableSystemProxy();
      notifyListeners();
    }
  }

  Future<bool> testConnection() async {
    const testUrls = [
      'https://www.google.com',
      'https://www.youtube.com',
      'https://www.facebook.com'
    ];

    for (final url in testUrls) {
      try {
        final result = await Process.run('curl', [
          '-v',
          '--connect-timeout', '10',
          '--max-time', '15',
          '-x', 'http://127.0.0.1:7899',
          url
        ]);
        
        if (result.exitCode == 0) {
          return true;
        }
      } catch (e) {
        continue;
      }
    }
    return false;
  }
  
  Future<void> disconnect() async {
    await V2RayService.stop();
    await ProxyService.disableSystemProxy();
    _isConnected = false;
    notifyListeners();
  }
  
  Future<void> setCurrentServer(ServerModel? server) async {
    _currentServer = server;
    await _saveCurrentServer();
    notifyListeners();
  }
}