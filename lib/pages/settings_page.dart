import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connection_provider.dart';
import '../services/autostart_service.dart';
import '../services/vless_config_service.dart';
import 'add_vless_config_page.dart';
import 'vless_config_list_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _autoStart = false;
  List<String> _hostList = [];
  String? _selectedHost;

  @override
  void initState() {
    super.initState();
    _loadAutoStartStatus();
    _loadHostList();
  }

  Future<void> _loadAutoStartStatus() async {
    final enabled = AutoStartService.isAutoStartEnabled();
    setState(() {
      _autoStart = enabled;
    });
  }

  Future<void> _loadHostList() async {
    final hosts = await VlessConfigService.getHostList();
    final connectionProvider = Provider.of<ConnectionProvider>(context, listen: false);
    String? verifiedConfig = connectionProvider.verifiedConfig;
    
    setState(() {
      _hostList = hosts;
      if (hosts.isNotEmpty) {
        if (verifiedConfig != null) {
          try {
            final uri = Uri.parse(verifiedConfig.trim());
            final currentHost = uri.queryParameters['host'];
            if (currentHost != null && hosts.contains(currentHost)) {
              _selectedHost = currentHost;
              return;
            }
          } catch (e) {
            print('解析当前配置失败: $e');
          }
        }
        _selectedHost = hosts.first;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          const _SectionHeader(title: '自建节点设置'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _selectedHost ?? '未选择节点',
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const VlessConfigListPage(),
                        ),
                      );
                      _loadHostList();
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Divider(),
          const _SectionHeader(title: '通用设置'),
          _SettingSwitch(
            title: '开机自启',
            subtitle: '系统启动时自动连接',
            value: _autoStart,
            onChanged: (value) async {
              final success = await AutoStartService.setAutoStart(value);
              if (success) {
                setState(() {
                  _autoStart = value;
                });
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('设置开机自启动失败'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
          ),
          _SettingSwitch(
            title: '自动连接',
            subtitle: '启动应用时自动连接',
            value: Provider.of<ConnectionProvider>(context).autoConnect,
            onChanged: (value) {
              Provider.of<ConnectionProvider>(context, listen: false)
                  .setAutoConnect(value);
            },
          ),
          const SizedBox(height: 20),
          const Divider(),
          _SettingTile(
            title: '当前版本',
            subtitle: 'v1.0.2',
            onTap: () {},
          ),
          _SettingTile(
            title: 'github地址',
            subtitle: 'https://github.com/jesee/cfvpn',
            onTap: () {},
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  const _SettingTile({
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: trailing,
      onTap: onTap,
    );
  }
}

class _SettingSwitch extends StatefulWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_SettingSwitch> createState() => _SettingSwitchState();
}

class _SettingSwitchState extends State<_SettingSwitch> {
  late bool _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(widget.title),
      subtitle: Text(widget.subtitle),
      value: _value,
      onChanged: (value) {
        setState(() {
          _value = value;
        });
        widget.onChanged(value);
      },
    );
  }
}