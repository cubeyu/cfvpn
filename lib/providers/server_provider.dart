import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/server_model.dart';

class ServerProvider with ChangeNotifier {
  List<ServerModel> _servers = [];
  final String _storageKey = 'servers';
  
  List<ServerModel> get servers => _servers;

  ServerProvider() {
    _loadServers();
  }

  Future<void> _loadServers() async {
    final prefs = await SharedPreferences.getInstance();
    final String? serversJson = prefs.getString(_storageKey);
    
    if (serversJson != null) {
      final List<dynamic> decoded = jsonDecode(serversJson);
      _servers = decoded.map((item) => ServerModel.fromJson(item)).toList();
    } else {
      // 默认服务器列表
      _servers = [
        ServerModel(
          id: '1',
          name: '香港 01',
          location: '香港',
          ip: '192.168.1.1',
          port: 443,
          ping: 65,
        ),
        ServerModel(
          id: '2',
          name: '日本 01',
          location: '东京',
          ip: '192.168.1.2',
          port: 443,
          ping: 85,
        ),
      ];
      _saveServers();
    }
    notifyListeners();
  }

  Future<void> _saveServers() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_servers.map((s) => s.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }

  Future<void> addServer(ServerModel server) async {
    _servers.add(server);
    await _saveServers();
    notifyListeners();
  }

  Future<void> updateServer(ServerModel server) async {
    final index = _servers.indexWhere((s) => s.id == server.id);
    if (index != -1) {
      _servers[index] = server;
      await _saveServers();
      notifyListeners();
    }
  }

  Future<void> deleteServer(String id) async {
    _servers.removeWhere((s) => s.id == id);
    await _saveServers();
    notifyListeners();
  }

  Future<void> updatePingAndSpeed(String id, int ping, int downloadSpeed) async {
    final index = _servers.indexWhere((s) => s.id == id);
    if (index != -1) {
      _servers[index].ping = ping;
      _servers[index].downloadSpeed = downloadSpeed;
      await _saveServers();
      notifyListeners();
    }
  }

  Future<void> clearServers() async {
    _servers.clear();
    await _saveServers();
    notifyListeners();
  }
}