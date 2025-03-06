import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  // 添加排序状态
  bool _isAscending = true;

  void _addServer(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新增服务器'),
        content: AddServerDialog(),
      ),
    );
  }

  void _addCloudflareServer(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('从 Cloudflare 添加服务器'),
        content: const CloudflareTestDialog(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('服务器列表'),
        centerTitle: true,
        actions: [
          // 测试延迟按钮
          IconButton(
            icon: const Icon(Icons.speed),
            tooltip: '测试延迟',
            onPressed: () {
              final serverProvider = context.read<ServerProvider>();
              // 模拟测试延迟
              for (var server in serverProvider.servers) {
                serverProvider.updatePing(server.id, 50 + (DateTime.now().millisecond % 200));
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('延迟测试完成')),
              );
            },
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
          // 新增服务器按钮
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新增服务器',
            onPressed: () => _addServer(context),
          ),
          IconButton(
            icon: const Icon(Icons.cloud),
            tooltip: '从 Cloudflare 添加',
            onPressed: () => _addCloudflareServer(context),
          ),
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
              Text('延迟: ${server.ping}ms'),
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