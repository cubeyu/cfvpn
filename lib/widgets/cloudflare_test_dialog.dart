import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/cloudflare_test_service.dart';
import '../providers/server_provider.dart';
import '../providers/connection_provider.dart';

class CloudflareTestDialog extends StatefulWidget {
  const CloudflareTestDialog({super.key});

  @override
  State<CloudflareTestDialog> createState() => _CloudflareTestDialogState();
}

class _CloudflareTestDialogState extends State<CloudflareTestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _countController = TextEditingController(text: '1');
  final _latencyController = TextEditingController(text: '300');
  final _speedController = TextEditingController(text: '1');
  final _testCountController = TextEditingController(text: '50');
  bool _isLoading = false;
  bool _showTip = false;

  @override
  void dispose() {
    _countController.dispose();
    _latencyController.dispose();
    _speedController.dispose();
    _testCountController.dispose();
    super.dispose();
  }

  Future<void> _startTest() async {
    if (!_formKey.currentState!.validate()) return;

    final connectionProvider = context.read<ConnectionProvider>();
    if (connectionProvider.isConnected) {
      if (!mounted) return;
      
      final shouldContinue = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('警告'),
          content: const Text('测试前需要断开当前连接，是否继续？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('继续'),
            ),
          ],
        ),
      ) ?? false;

      if (!shouldContinue) return;

      await connectionProvider.disconnect();
    }

    setState(() {
      _isLoading = true;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _isLoading) {
        setState(() {
          _showTip = true;
        });
      }
    });

    try {
      final servers = await CloudflareTestService.testServers(
        count: int.parse(_countController.text),
        maxLatency: int.parse(_latencyController.text),
        speed: int.parse(_speedController.text),
        testCount: int.parse(_testCountController.text),
      );

      if (!mounted) return;

      final serverProvider = context.read<ServerProvider>();
      for (var server in servers) {
        await serverProvider.addServer(server);
      }

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('成功添加 ${servers.length} 个服务器')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('测试失败: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _showTip = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _countController,
            decoration: const InputDecoration(
              labelText: '新增数量（要添加的服务器数量）',
              helperText: '',
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) return '请输入数量';
              if (int.tryParse(value) == null) return '请输入有效数字';
              if (int.parse(value) < 1) return '数量必须大于0';
              return null;
            },
          ),
          TextFormField(
            controller: _latencyController,
            decoration: const InputDecoration(
              labelText: '延迟上限（最大延迟(ms)）',
              helperText: '',
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) return '请输入延迟上限';
              if (int.tryParse(value) == null) return '请输入有效数字';
              if (int.parse(value) < 1) return '延迟必须大于0';
              return null;
            },
          ),
          TextFormField(
            controller: _speedController,
            decoration: const InputDecoration(
              labelText: '最低网速（最低网速要求(MB/s)）',
              helperText: '',
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) return '请输入网速要求';
              if (int.tryParse(value) == null) return '请输入有效数字';
              if (int.parse(value) < 1) return '网速必须大于0';
              return null;
            },
          ),
          TextFormField(
            controller: _testCountController,
            decoration: const InputDecoration(
              labelText: '延迟测试数量（延迟测试符合的ip个数）',
              helperText: '',
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) return '请输入测试次数';
              if (int.tryParse(value) == null) return '请输入有效数字';
              if (int.parse(value) < 1) return '测试次数必须大于0';
              return null;
            },
          ),
          const SizedBox(height: 16),
          if (_showTip)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '正在获取节点，请耐心等候...',
                style: TextStyle(color: Theme.of(context).primaryColor),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _isLoading ? null : () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isLoading ? null : _startTest,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('开始测试'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}