import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

class AddVlessConfigPage extends StatefulWidget {
  const AddVlessConfigPage({super.key});

  @override
  State<AddVlessConfigPage> createState() => _AddVlessConfigPageState();
}

class _AddVlessConfigPageState extends State<AddVlessConfigPage> {
  final _configController = TextEditingController();

  @override
  void dispose() {
    _configController.dispose();
    super.dispose();
  }

  Future<void> _saveConfig() async {
    final exePath = Platform.resolvedExecutable;
    final exeDir = path.dirname(exePath);
    final configPath = path.join(exeDir, 'vless.conf');
    final configFile = File(configPath);

    String newConfig = _configController.text.trim();
    String existingContent = '';

    if (await configFile.exists()) {
      existingContent = await configFile.readAsString();
    }

    // 将新配置添加到文件开头
    await configFile.writeAsString('$newConfig\n$existingContent');

    if (!mounted) return;
    Navigator.of(context).pop(true); // 返回true表示配置已更新
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('添加VLESS配置'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(false), // 返回false表示没有更新配置
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '示例配置：\nvless://bc24baea-3e5c-4107-a231-416cf00504fe@visa.cn:80?encryption=none&security=&sni=www.workers.dev&fp=randomized&type=ws&host=www.workers.dev&path=/?ed=2560#edgetunnel',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _configController,
              decoration: const InputDecoration(
                labelText: '输入VLESS配置',
                border: OutlineInputBorder(),
              ),
              maxLines: 8,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveConfig,
              child: const Text('提交'),
            ),
          ],
        ),
      ),
    );
  }
}