import 'dart:io';
import 'package:path/path.dart' as path;

class VlessConfigService {
  static Future<List<String>> getHostList() async {
    final exePath = Platform.resolvedExecutable;
    final exeDir = path.dirname(exePath);
    final configPath = path.join(exeDir, 'vless.conf');
    
    if (!await File(configPath).exists()) {
      return [];
    }

    final lines = await File(configPath).readAsLines();
    final hosts = <String>[];
print('lines：');
print(lines);


    for (var line in lines) {
      final uri = Uri.parse(line.trim());
      final host = uri.queryParameters['host'];
      if (host != null && host.isNotEmpty) {
        hosts.add(host);
      }
    }
    print("hosts：");
    print(hosts);

    return hosts;
  }

  static Future<String?> getCurrentConfig() async {
    final exePath = Platform.resolvedExecutable;
    final exeDir = path.dirname(exePath);
    final configPath = path.join(exeDir, 'vless.conf');
    
    if (!await File(configPath).exists()) {
      return null;
    }

    final lines = await File(configPath).readAsLines();
    if (lines.isEmpty) {
      return null;
    }

    return lines[0].trim();
  }

  static Future<String?> getHostFromConfig(String config) async {
    try {
      final uri = Uri.parse(config.trim());
      return uri.queryParameters['host'];
    } catch (e) {
      print('解析配置失败: $e');
      return null;
    }
  }
}