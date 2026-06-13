import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('고객센터'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showCustomerSupport(context),
          ),
        ],
      ),
    );
  }

  void _showCustomerSupport(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '고객센터 연결',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFE812), // Kakao Yellow
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.chat, color: Colors.black, size: 20),
                  ),
                  title: const Text('카카오톡'),
                  onTap: () async {
                    Navigator.pop(context);
                    await launchUrl(
                      Uri.parse('https://open.kakao.com/o/sftQLozi'),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFF06C755), // Line Green
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.message, color: Colors.white, size: 20),
                  ),
                  title: const Text('라인'),
                  onTap: () async {
                    Navigator.pop(context);
                    await launchUrl(
                      Uri.parse('https://line.me/ti/g2/-CCiaKCx87hclDxnFulTVvqLKshaAOdn0NtXnQ?utm_source=invitation&utm_medium=link_copy&utm_campaign=default'),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
