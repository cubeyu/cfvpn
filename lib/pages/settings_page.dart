import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connection_provider.dart';
import '../services/autostart_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _autoStart = false;

  @override
  void initState() {
    super.initState();
    _loadAutoStartStatus();
  }

  Future<void> _loadAutoStartStatus() async {
    final enabled = AutoStartService.isAutoStartEnabled();
    setState(() {
      _autoStart = enabled;
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
          //作者信息
          _SettingTile(
            title: '作者信息',
            subtitle: 'JeseeLin',
            onTap: () {},
          ),
          _SettingTile(
            title: 'github地址',
            subtitle: 'https://github.com/jesee/cfvpn',
            onTap: () {},
          ),
          _SettingTile(
            title: '当前版本',
            subtitle: 'v1.0.1',
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