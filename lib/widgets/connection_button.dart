import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connection_provider.dart';

class ConnectionButton extends StatelessWidget {
  const ConnectionButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectionProvider>(
      builder: (context, provider, child) {
        final bool isConnected = provider.isConnected;
        final bool isConnecting = provider.isConnecting;
        final String? error = provider.connectionError;
        
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () {
                if (isConnecting) {
                  provider.disconnect();
                } else if (isConnected) {
                  provider.disconnect();
                } else {
                  provider.connect();
                }
              },
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isConnected ? Colors.green : Colors.blue,
                  boxShadow: [
                    BoxShadow(
                      color: (isConnected ? Colors.green : Colors.blue).withOpacity(0.3),
                      spreadRadius: 5,
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (!isConnecting)
                      Icon(
                        isConnected ? Icons.power_settings_new : Icons.power_off,
                        size: 60,
                        color: Colors.white,
                      ),
                    if (isConnecting)
                      const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 5,
                      ),
                  ],
                ),
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(
                  error,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}