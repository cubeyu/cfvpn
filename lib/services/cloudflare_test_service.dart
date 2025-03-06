import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import '../models/server_model.dart';

class CloudflareTestService {
  static Future<String> _getExecutablePath() async {
    if (Platform.isWindows) {
      // 获取应用程序可执行文件所在目录
      final exePath = Platform.resolvedExecutable;
      final directory = path.dirname(exePath);
      return path.join(directory, 'cftest.exe');
    }
    throw 'Unsupported platform';
  }

  static Future<List<ServerModel>> testServers({
    required int count,
    required int maxLatency,
    required int speed,
    String location = 'HKG',
  }) async {
    final exePath = await _getExecutablePath();
    final resultPath = path.join(path.dirname(exePath), 'result.json');
    final ipFilePath = path.join(path.dirname(exePath), 'ip.txt');
    
    // 添加调试信息
    print('Executable path: $exePath');
    print('IP file path: $ipFilePath');
    print('Result path: $resultPath');
    
    // 检查文件是否存在
    if (!await File(exePath).exists()) {
      throw 'cftest.exe not found at: $exePath';
    }
    if (!await File(ipFilePath).exists()) {
      throw 'ip.txt not found at: $ipFilePath';
    }

    try {
      final process = await Process.start(
        exePath,
        ['-f', ipFilePath, '-cfcolo', location, '-dn', '$count', '-tl', '$maxLatency', '-sl', '$speed'],
        workingDirectory: path.dirname(exePath),  // 设置工作目录
        mode: ProcessStartMode.inheritStdio,      // 继承标准输入输出
      );

      // 等待进程完成
      final exitCode = await process.exitCode;
      print('Process exit code: $exitCode');

      if (exitCode != 0) {
        throw 'Process exited with code $exitCode';
      }

      // 读取结果文件
      final resultFile = File(resultPath);
      if (!await resultFile.exists()) {
        throw 'Result file not found at: $resultPath';
      }

      final String jsonContent = await resultFile.readAsString();
      print('Result content: $jsonContent');  // 打印结果内容
      
      final List<dynamic> results = jsonDecode(jsonContent);
      
      // 转换为服务器列表
      final List<ServerModel> servers = [];
      int index = 1;
      
      for (var result in results) {
        final ip = result['ip'];
        servers.add(ServerModel(
          id: DateTime.now().millisecondsSinceEpoch.toString() + index.toString(),
          name: ip,  // 直接使用 IP 作为名称
          location: location,
          ip: ip,
          port: result['port'],
          ping: result['delay'],
        ));
        index++;
      }

      return servers;
    } catch (e) {
      throw 'Failed to test servers: $e';
    }
  }
} 