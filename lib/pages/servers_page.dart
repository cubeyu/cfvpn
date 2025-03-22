import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:proxy_app/services/v2ray_service.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'dart:convert';
import '../models/server_model.dart';
import '../providers/connection_provider.dart';
import '../providers/server_provider.dart';
import '../widgets/add_server_dialog.dart';
import '../widgets/cloudflare_test_dialog.dart';

class ServersPage extends StatefulWidget {
  const ServersPage({super.key});

  @override
  State<ServersPage> createState() => _ServersPageState();
}

class _ServersPageState extends State<ServersPage> {
  bool _isAscending = true;
  bool _isLoading = false;

  static Future<String> _getExecutablePath() async {
    return V2RayService.getExecutablePath('cftest.exe');
  }

  void _addCloudflareServer(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('从Cloudflare添加'),
        content: const CloudflareTestDialog(),
      ),
    );
  }

  // void _addServer(BuildContext context) {
  //   showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: const Text('新增服务器'),
  //       content: const AddServerDialog(),
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('服务器列表'),
        centerTitle: true,
        actions: [
          // 测试延迟按钮
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.speed),
                tooltip: '测试延迟',
                onPressed: _isLoading ? null : () async {
                  final serverProvider = context.read<ServerProvider>();
                  final connectionProvider = context.read<ConnectionProvider>();

                  // 收集所有服务器的IP地址
                  final ips = serverProvider.servers.map((server) => server.ip).join(',');
                  if (ips.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('没有可测试的服务器')),
                    );
                    return;
                  }

                  // 检查连接状态
                  if (connectionProvider.isConnected) {
                    final shouldContinue = await showDialog<bool>(
                      context: context,
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

                  try {
                    // 执行测试命令
                    final exePath = await _getExecutablePath();
                    
                    final result = await Process.run(
                      exePath,
                      ['-ip', ips, '-tl', '300', '-sl', '0', '-dm', '50'],
                      workingDirectory: path.dirname(exePath),
                    );

                    // 检查进程退出码
                    if (result.exitCode != 0) {
                      throw '测试进程退出，错误代码：${result.exitCode}';
                    }

                    // 读取测试结果
                    final resultFile = File(path.join(path.dirname(exePath), 'result.json'));
                    if (!await resultFile.exists()) {
                      throw '未找到测试结果文件';
                    }

                    final String jsonContent = await resultFile.readAsString();
                    final List<dynamic> results = jsonDecode(jsonContent);

                    // 更新服务器延迟
                    for (var result in results) {
                      final ip = result['ip'];
                      final delay = result['delay'];
                      final downloadSpeed = result['downloadSpeed'];
                      final server = serverProvider.servers.firstWhere(
                        (server) => server.ip == ip,
                        orElse: () => ServerModel(
                          id: '',
                          name: '',
                          location: '',
                          ip: '',
                          port: 0,
                        ),
                      );
                      if (server.id.isNotEmpty) {
                        serverProvider.updatePingAndSpeed(server.id, delay, downloadSpeed);
                        // 如果是当前选中的服务器，更新ConnectionProvider中的数据
                        if (connectionProvider.currentServer?.id == server.id) {
                          connectionProvider.setCurrentServer(server);
                        }
                      }
                    }

                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('延迟测试完成')),
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
                      });
                    }
                  }
                },
              ),
              if (_isLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),
            ],
          ),
          // 排序按钮
          IconButton(
            icon: const Icon(Icons.sort),
            tooltip: _isAscending ? '延迟从低到高' : '延迟从高到低',
            onPressed: () {
              setState(() {
                _isAscending = !_isAscending;
              });
            },
          ),
          // 从cloudflare添加按钮
          IconButton(
            icon: const Icon(Icons.cloud),
            tooltip: '从Cloudflare添加',
            onPressed: () => _addCloudflareServer(context),
          ),
          // 删除所有服务器按钮
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: '删除所有服务器',
            onPressed: () async {
              final serverProvider = context.read<ServerProvider>();
              final connectionProvider = context.read<ConnectionProvider>();

              if (serverProvider.servers.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('没有可删除的服务器')),
                );
                return;
              }

              final shouldDelete = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('警告'),
                  content: const Text('确定要删除所有服务器吗？此操作不可恢复。'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('确定'),
                    ),
                  ],
                ),
              ) ?? false;

              if (!shouldDelete) return;

              // 如果当前有连接，先断开
              if (connectionProvider.isConnected) {
                await connectionProvider.disconnect();
              }

              // 删除所有服务器
              serverProvider.clearServers();

              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已删除所有服务器')),
              );
            },
          ),
          // 新增服务器按钮
          // IconButton(
          //   icon: const Icon(Icons.add),
          //   tooltip: '新增服务器',
          //   onPressed: () => _addServer(context),
          // ),
        ],
      ),
      body: Consumer2<ServerProvider, ConnectionProvider>(
        builder: (context, serverProvider, connectionProvider, child) {
          var servers = List<ServerModel>.from(serverProvider.servers);
          if (_isAscending) {
            servers.sort((a, b) => a.ping.compareTo(b.ping));
          } else {
            servers.sort((a, b) => b.ping.compareTo(a.ping));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: servers.length,
            itemBuilder: (context, index) {
              final server = servers[index];
              final isSelected = connectionProvider.currentServer?.id == server.id;
              
              return ServerListItem(
                server: server,
                isSelected: isSelected,
                onTap: () {
                  connectionProvider.setCurrentServer(server);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('已选择 ${server.name}'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class ServerListItem extends StatelessWidget {
  final ServerModel server;
  final bool isSelected;
  final VoidCallback onTap;

  const ServerListItem({
    super.key,
    required this.server,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Dismissible(
        key: Key(server.id),
        direction: DismissDirection.endToStart,
        confirmDismiss: (direction) async {
          return await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('确认删除'),
              content: Text('是否删除服务器 ${server.name}？'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('删除'),
                ),
              ],
            ),
          ) ?? false;
        },
        onDismissed: (direction) {
          context.read<ServerProvider>().deleteServer(server.id);
          final connectionProvider = context.read<ConnectionProvider>();
          if (connectionProvider.currentServer?.id == server.id) {
            connectionProvider.setCurrentServer(null);
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已删除 ${server.name}')),
          );
        },
        background: Container(
          color: Colors.red,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 16),
          child: const Icon(
            Icons.delete,
            color: Colors.white,
          ),
        ),
        child: ListTile(
          onTap: onTap,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.public,
              color: Colors.blue,
            ),
          ),
          title: Text(
            server.name,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('延迟: ${server.ping}ms'),
                  const SizedBox(width: 16),
                  Text('网速: ${server.downloadSpeed}MB/s'),
                ],
              ),
              Text('${server.ip}:${server.port}'),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.green,
                  ),
                ),
              _buildPingIndicator(server.ping),
            ],
          ),
          isThreeLine: true,
        ),
      ),
    );
  }

  Widget _buildPingIndicator(int ping) {
    Color color;
    int bars;

    if (ping < 80) {
      color = Colors.green;
      bars = 3;
    } else if (ping < 150) {
      color = Colors.orange;
      bars = 2;
    } else {
      color = Colors.red;
      bars = 1;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return Container(
          width: 3,
          height: 8 + (index * 4),
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: index < bars ? color : Colors.grey.withOpacity(0.3),
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }
}