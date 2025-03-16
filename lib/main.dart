import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'pages/home_page.dart';
import 'pages/servers_page.dart';
import 'pages/settings_page.dart';
import 'providers/connection_provider.dart';
import 'providers/server_provider.dart';

void main() {
  // 检查是否已有实例运行
  final lockFile = File('app.lock');
  try {
    // 尝试创建锁文件
    lockFile.createSync();
    // 注册退出时删除锁文件
    ProcessSignal.sigint.watch().listen((_) {
      lockFile.deleteSync();
      exit(0);
    });
  } catch (e) {
    // 如果文件已存在，说明已有实例在运行
    print('应用程序已在运行');
    exit(0);
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectionProvider()),
        ChangeNotifierProvider(create: (context) => ServerProvider(connectionProvider: Provider.of<ConnectionProvider>(context, listen: false))),
      ],
      child: MaterialApp(
        title: 'Proxy App',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: const MainScreen(),
        builder: (context, child) {
          return child!;
        },
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  
  final List<Widget> _pages = [
    const HomePage(),
    const ServersPage(),
    const SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '首页',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: '服务器',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}