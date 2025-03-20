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
  
  Future<void> connect() async {
    if (_currentServer != null && !_isConnecting) {
      _isConnecting = true;
      _connectionError = null;
      notifyListeners();

      try {
        final configFile = File('${await V2RayService.getExecutablePath("vless.conf")}');
        final originalConfig = await configFile.readAsString();
        final lines = originalConfig.split('\n');//这里按行分割可能有bug吧，应该要用EOF系统变量代替？
        
        if (lines.isEmpty) {
          _connectionError = "配置文件为空";
          _isConnecting = false;
          notifyListeners();
          return;
        }

        // 优先使用上次成功的配置
        if (_verifiedConfig != null) {
          // 对配置字符串进行预处理，移除多余的空白字符
          final normalizedVerifiedConfig = _verifiedConfig!.trim();
          final normalizedLines = lines.map((line) => line.trim()).toList();
          
          if (normalizedLines.contains(normalizedVerifiedConfig)) {
            // 如果有缓存的配置且在配置列表中，优先使用它
            _verifiedConfig = normalizedVerifiedConfig;
            _connectionError = "正在使用上次成功的配置连接...";
          } else {
            // 否则使用第一行配置
            _verifiedConfig = lines[0].trim();
            _connectionError = "正在启动代理服务...";
          }
        } else {
          // 如果没有缓存配置，使用第一行配置
          _verifiedConfig = lines[0].trim();
          _connectionError = "正在启动代理服务...";
        }
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
          
          if (!testResult) {
            _connectionError = "连通性测试失败，正在切换自建节点配置...";
            notifyListeners();
            
            if (lines.length <= 1) {
              _connectionError = "连接已建立，但访问受限";
              notifyListeners();
              return;
            }

            // 尝试切换到下一个配置
            for (var i = 1; i < lines.length; i++) {
              if (lines[i].trim().isEmpty) continue;
              
              _verifiedConfig = lines[i];
              await V2RayService.stop();
              final retrySuccess = await V2RayService.start(
                serverIp: _currentServer!.ip,
                serverPort: _currentServer!.port,
                verifiedConfig: _verifiedConfig,
              );

              if (retrySuccess) {
                await ProxyService.enableSystemProxy();
                await Future.delayed(const Duration(seconds: 5));
                _connectionError = "正在进行连通性测试...";
                notifyListeners();
                final retryTestResult = await testConnection();
                if (retryTestResult) {
                  _connectionError = "连通性测试成功";
                  notifyListeners();
                  // 保存成功的配置
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString(_verifiedConfigKey, _verifiedConfig!);
                  await Future.delayed(const Duration(seconds: 2));
                  _connectionError = null;
                  notifyListeners();
                  return;
                }
              }
            }
            
            _connectionError = "所有节点连接失败，请参考自建节点方案";
            await V2RayService.stop();
            await ProxyService.disableSystemProxy();
            _isConnected = false;
          } else {
            _connectionError = "连通性测试成功";
            notifyListeners();
            // 保存成功的配置
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_verifiedConfigKey, _verifiedConfig!);
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