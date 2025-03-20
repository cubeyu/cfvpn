import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;

class V2RayService {
  static Process? _v2rayProcess;
  static bool _isRunning = false;
  static bool get isRunning => _isRunning;

  static Future<String> getExecutablePath(String executableName) async {
    if (Platform.isWindows) {
      final exePath = Platform.resolvedExecutable;
      final directory = path.dirname(exePath);
      return path.join(directory, executableName);
    }
    throw 'Unsupported platform';
  }

  static Future<String> _getV2RayPath() async {
    return getExecutablePath(path.join('v2ray', 'v2ray.exe'));
  }

  static Future<Map<String, dynamic>> parseVlessConfig() async {
    try {
      final vlessPath = path.join(
        path.dirname(Platform.resolvedExecutable),
        'vless.conf'
      );
      
      final content = await File(vlessPath).readAsString();
      final uri = Uri.parse(content.trim().replaceFirst('vless://', 'https://'));
      
      // 解析查询参数
      final queryParams = uri.queryParameters;
      
      return {
        'id': uri.userInfo,
        'address': uri.host,
        'port': uri.port,
        'encryption': queryParams['encryption'] ?? 'none',
        'security': queryParams['security'] ?? 'none',
        'sni': queryParams['sni'] ?? '',
        'fp': queryParams['fp'] ?? 'randomized',
        'type': queryParams['type'] ?? 'ws',
        'host': queryParams['host'] ?? '',
        'path': queryParams['path'] ?? '/',
      };
    } catch (e) {
      print('解析 vless 配置失败: $e');
      rethrow;
    }
  }

  static Future<void> generateConfig({
    required String serverIp,
    required int serverPort,
    int localPort = 7898,
    int httpPort = 7899,
  }) async {
    final vlessConfig = await parseVlessConfig();
    final v2rayPath = await _getV2RayPath();
    final configPath = path.join(
      path.dirname(v2rayPath),
      'config.json'
    );

    final inbounds = [
      {
        "port": localPort,
        "protocol": "socks",
        "settings": {
          "auth": "noauth",
          "udp": true
        }
      },
      {
        "tag": "http",
        "port": httpPort,
        "protocol": "http",
        "sniffing": {
          "enabled": true,
          "destOverride": [
            "http",
            "tls"
          ],
          "routeOnly": false
        },
        "settings": {
          "auth": "noauth",
          "udp": true,
          "allowTransparent": false
        }
      }
    ];

    final config = {
      "inbounds": inbounds,
      "outbounds": [
        {
          "tag": "proxy",
          "protocol": "vless",
          "settings": {
            "vnext": [
              {
                "address": serverIp,
                "port": vlessConfig['port'],
                "users": [
                  {
                    "id": vlessConfig['id'],
                    "alterId": 0,
                    "email": "t@t.tt",
                    "security": "auto",
                    "encryption": vlessConfig['encryption']
                  }
                ]
              }
            ]
          },
          "streamSettings": {
            "network": vlessConfig['type'],
            "security": vlessConfig['security'],
            "wsSettings": {
              "path": vlessConfig['path'],
              "headers": {
                "Host": vlessConfig['host']
              }
            },
            "sockopt": {
              "dialerProxy": "proxy3"
            }
          },
          "mux": {
            "enabled": false,
            "concurrency": -1
          }
        },
        {
          "tag": "direct",
          "protocol": "freedom",
          "settings": {}
        },
        {
          "tag": "block",
          "protocol": "blackhole",
          "settings": {
            "response": {
              "type": "http"
            }
          }
        },
        {
          "tag": "proxy3",
          "protocol": "freedom",
          "settings": {
            "fragment": {
              "packets": "tlshello",
              "length": "100-200",
              "interval": "10-20"
            }
          }
        }
      ],
      "dns": {
        "hosts": {
          "dns.google": "8.8.8.8",
          "proxy.example.com": "127.0.0.1"
        },
        "servers": [
          {
            "address": "223.5.5.5",
            "domains": [
              "geosite:cn",
              "geosite:geolocation-cn"
            ],
            "expectIPs": [
              "geoip:cn"
            ]
          },
          "1.1.1.1",
          "8.8.8.8",
          "https://dns.google/dns-query"
        ]
      },
      "routing": {
        "domainStrategy": "AsIs",
        "rules": [
          {
            "type": "field",
            "inboundTag": [
              "api"
            ],
            "outboundTag": "api"
          },
          {
            "type": "field",
            "outboundTag": "direct",
            "domain": [
              "domain:example-example.com",
              "domain:example-example2.com",
              "domain:3o91888o77.vicp.fun"
            ]
          },
          {
            "type": "field",
            "port": "443",
            "network": "udp",
            "outboundTag": "block"
          },
          {
            "type": "field",
            "outboundTag": "block",
            "domain": [
              "geosite:category-ads-all"
            ]
          },
          {
            "type": "field",
            "outboundTag": "direct",
            "domain": [
              "domain:dns.alidns.com",
              "domain:doh.pub",
              "domain:dot.pub",
              "domain:doh.360.cn",
              "domain:dot.360.cn",
              "geosite:cn",
              "geosite:geolocation-cn"
            ]
          },
          {
            "type": "field",
            "outboundTag": "direct",
            "ip": [
              "223.5.5.5/32",
              "223.6.6.6/32",
              "2400:3200::1/128",
              "2400:3200:baba::1/128",
              "119.29.29.29/32",
              "1.12.12.12/32",
              "120.53.53.53/32",
              "2402:4e00::/128",
              "2402:4e00:1::/128",
              "180.76.76.76/32",
              "2400:da00::6666/128",
              "114.114.114.114/32",
              "114.114.115.115/32",
              "180.184.1.1/32",
              "180.184.2.2/32",
              "101.226.4.6/32",
              "218.30.118.6/32",
              "123.125.81.6/32",
              "140.207.198.6/32",
              "geoip:private",
              "geoip:cn"
            ]
          },
          {
            "type": "field",
            "port": "0-65535",
            "outboundTag": "proxy"
          }
        ]
      }
    };

    await File(configPath).writeAsString(jsonEncode(config));
  }

  static Future<bool> isPortAvailable(int port) async {
    try {
      final socket = await ServerSocket.bind('127.0.0.1', port, shared: true);
      await socket.close();
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> start({
    required String serverIp,
    required int serverPort,
  }) async {
    if (_isRunning) {
      await stop();  // 确保先停止旧进程
    }

    try {
      // 检查端口是否可用
      if (!await isPortAvailable(7898) || !await isPortAvailable(7899)) {
        return false;
      }

      await generateConfig(
        serverIp: serverIp,
        serverPort: serverPort,
      );

      final v2rayPath = await _getV2RayPath();
      _v2rayProcess = await Process.start(
        v2rayPath,
        ['run'],
        workingDirectory: path.dirname(v2rayPath),
      );

      _isRunning = true;
      return true;
    } catch (e) {
      print('启动V2Ray失败: $e');
      return false;
    }
  }

  static Future<void> stop() async {
    if (_v2rayProcess != null) {
      _v2rayProcess!.kill();
      _v2rayProcess = null;
    }
    _isRunning = false;
  }
}