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
        // 首先检查是否有已验证的配置
        final verifiedConfigFile = File('${await V2RayService.getExecutablePath("verified_vless.conf")}');
        if (verifiedConfigFile.existsSync()) {
          final verifiedConfig = await verifiedConfigFile.readAsString();
          final configFile = File('${await V2RayService.getExecutablePath("vless.conf")}');
          await configFile.writeAsString(verifiedConfig);
        }

        _connectionError = "正在启动代理服务...";  // 添加启动状态提示
        notifyListeners();
        
        final success = await V2RayService.start(
          serverIp: _currentServer!.ip,
          serverPort: _currentServer!.port,
        );

        if (success) {
          _connectionError = "正在配置系统代理...";  // 添加代理配置状态提示
          notifyListeners();
          await ProxyService.enableSystemProxy();
          _isConnected = true;
          _isConnecting = false;
          _connectionError = "正在等待网络稳定...";
          notifyListeners();
          
          // 延迟5秒后进行连通性测试
          await Future.delayed(const Duration(seconds: 5));
          _connectionError = "正在进行连通性测试...";  // 添加测试状态提示
          notifyListeners();
          final testResult = await testConnection();
          if (!testResult) {
            _connectionError = "连通性测试失败，正在切换自建节点配置...";
            notifyListeners();
            // 检查是否有多行配置
            final configFile = File('${await V2RayService.getExecutablePath("vless.conf")}');
            if (!configFile.existsSync()) {
              _connectionError = "连接已建立，但访问受限";
              notifyListeners();
              return;
            }
            final lines = await configFile.readAsLines();
            if (lines.length <= 1) {
              _connectionError = "连接已建立，但访问受限";
              notifyListeners();
              return;
            }

            // 尝试切换到下一个配置
            for (var i = 1; i < lines.length; i++) {
              if (lines[i].trim().isEmpty) continue;
              
              // 更新配置文件为当前行
              await configFile.writeAsString(lines[i]);
              
              // 重新启动连接
              await V2RayService.stop();
              final retrySuccess = await V2RayService.start(
                serverIp: _currentServer!.ip,
                serverPort: _currentServer!.port,
              );

              if (retrySuccess) {
                await ProxyService.enableSystemProxy();
                await Future.delayed(const Duration(seconds: 5));
                _connectionError = "正在进行连通性测试...";  // 添加测试状态提示
                notifyListeners();
                final retryTestResult = await testConnection();
                if (retryTestResult) {
                  _connectionError = "连通性测试成功";
                  notifyListeners();
                  // 保存当前可用的配置
                  final verifiedConfigFile = File('${await V2RayService.getExecutablePath("verified_vless.conf")}');
                  final currentConfig = await configFile.readAsString();
                  await verifiedConfigFile.writeAsString(currentConfig);
                  await Future.delayed(const Duration(seconds: 2));
                  _connectionError = null;
                  notifyListeners();
                  return;
                }
              }
            }
            
            // 所有配置都尝试失败
            _connectionError = "所有节点连接失败，请参考自建节点方案";
            await V2RayService.stop();
            await ProxyService.disableSystemProxy();
            _isConnected = false;
          } else {
            _connectionError = "连通性测试成功";
            notifyListeners();
            await Future.delayed(const Duration(seconds: 2));
            _connectionError = null;
          }
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