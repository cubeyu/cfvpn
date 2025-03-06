import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

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
            value: false,
            onChanged: (value) {
              // TODO: 实现开机自启动功能
            },
          ),
          _SettingSwitch(
            title: '自动重连',
            subtitle: '断开连接时自动重连',
            value: true,
            onChanged: (value) {
              // TODO: 实现自动重连功能
            },
          ),
          const Divider(),
          
          const _SectionHeader(title: '网络设置'),
          _SettingTile(
            title: '代理模式',
            subtitle: '全局代理',
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: 打开代理模式选择
            },
          ),
          _SettingTile(
            title: '路由设置',
            subtitle: '配置分流规则',
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: 打开路由设置
            },
          ),
          const Divider(),
          
          const _SectionHeader(title: '关于'),
          _SettingTile(
            title: '当前版本',
            subtitle: 'v1.0.0',
            onTap: () {},
          ),
          _SettingTile(
            title: '检查更新',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('已是最新版本'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          _SettingTile(
            title: '隐私政策',
            onTap: () {
              // TODO: 打开隐私政策
            },
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton(
              onPressed: () {
                // TODO: 实现清除缓存功能
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('缓存已清除'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              child: const Text('清除缓存'),
            ),
          ),
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