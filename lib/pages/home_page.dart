import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connection_provider.dart';
import '../widgets/connection_button.dart';
import '../widgets/server_info_card.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('代理'),
        centerTitle: true,
      ),
      body: Consumer<ConnectionProvider>(
        builder: (context, provider, child) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 连接状态
                Text(
                  provider.isConnected ? '已连接' : '未连接',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: provider.isConnected ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(height: 20),
                
                // 服务器信息卡片
                if (provider.currentServer != null)
                  ServerInfoCard(server: provider.currentServer!),
                
                const SizedBox(height: 40),
                
                // 连接按钮
                const ConnectionButton(),
                
                const SizedBox(height: 40),
                
                // 简单的流量统计
                if (provider.isConnected) ...[
                  const Text(
                    '已使用流量',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '0.00 MB',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
} 