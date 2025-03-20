import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connection_provider.dart';
import '../services/vless_config_service.dart';
import 'add_vless_config_page.dart';

class VlessConfigListPage extends StatefulWidget {
  const VlessConfigListPage({super.key});

  @override
  State<VlessConfigListPage> createState() => _VlessConfigListPageState();
}

class _VlessConfigListPageState extends State<VlessConfigListPage> {
  List<String> _hostList = [];

  @override
  void initState() {
    super.initState();
    _loadHostList();
  }

  Future<void> _loadHostList() async {
    final hosts = await VlessConfigService.getHostList();
    setState(() {
      _hostList = hosts;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('自建节点列表'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final configUpdated = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddVlessConfigPage(),
                ),
              );
              if (configUpdated == true) {
                _loadHostList();
              }
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _hostList.length,
        itemBuilder: (context, index) {
          final host = _hostList[index];
          return ListTile(
            title: Text(host),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('确认删除'),
                    content: Text('确定要删除节点 "$host" 吗？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('确定'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await VlessConfigService.deleteHost(host);
                  _loadHostList();
                }
              },
            ),
            onTap: () {
              Provider.of<ConnectionProvider>(context, listen: false)
                  .setSelectedHost(host);
              Navigator.of(context).pop();
            },
          );
        },
      ),
    );
  }
}