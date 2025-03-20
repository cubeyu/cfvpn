import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/server_model.dart';
import '../services/v2ray_service.dart';
import '../services/vless_config_service.dart';
import '../services/proxy_service.dart';

class ConnectionProvider with ChangeNotifier {
  bool _isConnected = false;
  bool _isConnecting = false;
  String? _connectionError;
  ServerModel? _currentServer;
  final String _storageKey = 'current_server';
  bool _autoConnect = false;
  String? _verifiedConfig;  // 添加缓存变量存储已验证的配置
  final String _verifiedConfigKey = 'verified_config';  // 添加存储键
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String? get connectionError => _connectionError;
  ServerModel? get currentServer => _currentServer;
  bool get autoConnect => _autoConnect;
  String? get verifiedConfig => _verifiedConfig;
  
  ConnectionProvider() {
    // 启动时先进行清理操作
    _cleanupOnStartup();
    _loadSettings();
    _loadCurrentServer();
  }

  Future<void> _cleanupOnStartup() async {
    try {
      // 停止可能存在的 V2Ray 进程
      await V2RayService.stop();
      // 禁用系统代理
      await ProxyService.disableSystemProxy();
    } catch (e) {
      print('清理操作失败: $e');
    }
  }
  
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _autoConnect = prefs.getBool('auto_connect') ?? false;
    _verifiedConfig = prefs.getString(_verifiedConfigKey);
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

  Future<void> setSelectedHost(String host) async {
    final configFile = File('${await V2RayService.getExecutablePath("vless.conf")}');
    if (await configFile.exists()) {
      final lines = await configFile.readAsLines();
      for (var line in lines) {
        if (line.trim().isEmpty) continue;
        try {
          final uri = Uri.parse(line.trim());
          final configHost = uri.queryParameters['host'];
          if (configHost == host) {
            _verifiedConfig = line.trim();
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_verifiedConfigKey, _verifiedConfig!);
            break;
          }
        } catch (e) {
          continue;
        }
      }
    }
    print('_verifiedConfig 点击自建列表确定后：');
    print(_verifiedConfig);
    notifyListeners();
  }
  
  Future<void> connect() async {
    if (_currentServer != null && !_isConnecting) {
      _isConnecting = true;
      _connectionError = null;
      notifyListeners();

      try {
        final configFile = File('${await V2RayService.getExecutablePath("vless.conf")}');
        final originalConfig = await configFile.readAsString();
        final lines = originalConfig.split('\n');
        
        if (lines.isEmpty) {
          _connectionError = "配置文件为空";
          _isConnecting = false;
          notifyListeners();
          return;
        }

        bool foundMatchingConfig = false;
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].trim().isEmpty) continue;
          
          final currentConfig = lines[i].trim();
          if (_verifiedConfig != null) {
            // 如果有已验证的配置，优先尝试匹配的配置
            if (currentConfig == _verifiedConfig!.trim()) {
              foundMatchingConfig = true;
            } else {
              continue; // 如果不匹配，继续下一个
            }
          }

          _verifiedConfig = currentConfig;
          _connectionError = foundMatchingConfig ? "正在使用上次成功的配置连接..." : "正在启动代理服务...";
          notifyListeners();

          final success = await V2RayService.start(
            serverIp: _currentServer!.ip,
            serverPort: _currentServer!.port,
            verifiedConfig: _verifiedConfig,
          );

          if (success) {
            _connectionError = "正在配置系统代理...";
            notifyListeners();
            await ProxyService.enableSystemProxy();
            _isConnected = true;
            _isConnecting = false;
            _connectionError = "正在等待网络稳定...";
            notifyListeners();
            
            await Future.delayed(const Duration(seconds: 5));
            _connectionError = "正在进行连通性测试...";
            notifyListeners();
            final testResult = await testConnection();
            
            if (testResult) {
              _connectionError = "连通性测试成功";
              notifyListeners();
              // 保存成功的配置
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(_verifiedConfigKey, _verifiedConfig!);
              await Future.delayed(const Duration(seconds: 2));
              _connectionError = null;
              notifyListeners();
              return;
            } else {
              // 测试失败，停止当前连接
              await V2RayService.stop();
              await ProxyService.disableSystemProxy();
              if (foundMatchingConfig) {
                _connectionError = "连通性测试失败，正在切换到下一个自建节点...";
                notifyListeners();
                //延迟2秒
                await Future.delayed(const Duration(seconds: 2));
                // 如果是验证过的配置失败，重置验证配置
                _verifiedConfig = null;
                foundMatchingConfig = false;
                continue;
              }
            }
          }
        }
        
        // 所有配置都尝试完毕但都失败了
        _connectionError = "所有节点连接失败，请参考自建节点方案";
        _isConnected = false;
        _isConnecting = false;
        notifyListeners();
      } catch (e) {
        _connectionError = e.toString();
        await V2RayService.stop();
        await ProxyService.disableSystemProxy();
        _isConnecting = false;
      } finally {
        notifyListeners();
      }
    } else if (_isConnecting) {
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