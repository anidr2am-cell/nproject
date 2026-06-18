import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import '../constants/colors.dart';

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
            leading: const Icon(Icons.help_outline, color: brandPrimary),
            title: const Text('고객센터', style: TextStyle(color: brandInk, fontWeight: FontWeight.w500)),
            trailing: const Icon(Icons.chevron_right, color: brandMuted),
            onTap: () => _showCustomerSupport(context),
          ),
          const Divider(height: 1, color: brandBorder),
        ],
      ),
    );
  }

  void _showCustomerSupport(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: brandBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text(
                  '고객센터 연결',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: brandPrimary),
                ),
                const SizedBox(height: 24),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEE500), // Kakao Yellow
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.chat, color: Colors.black, size: 20),
                  ),
                  title: const Text('카카오톡 상담하기', style: TextStyle(fontWeight: FontWeight.w500)),
                  trailing: const Icon(Icons.open_in_new, size: 16, color: brandMuted),
                  onTap: () async {
                    Navigator.pop(context);
                    const url = 'https://open.kakao.com/o/sftQLozi';
                    if (kIsWeb) {
                      final anchor = html.AnchorElement()
                        ..href = url
                        ..target = '_blank'
                        ..rel = 'noopener noreferrer';
                      html.document.body?.append(anchor);
                      anchor.click();
                      anchor.remove();
                    } else {
                      await launchUrl(Uri.parse(url),
                        mode: LaunchMode.externalApplication);
                    }
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
                    const url = 'https://line.me/ti/g2/-CCiaKCx87hclDxnFulTVvqLKshaAOdn0NtXnQ?utm_source=invitation&utm_medium=link_copy&utm_campaign=default';
                    if (kIsWeb) {
                      final anchor = html.AnchorElement()
                        ..href = url
                        ..target = '_blank'
                        ..rel = 'noopener noreferrer';
                      html.document.body?.append(anchor);
                      anchor.click();
                      anchor.remove();
                    } else {
                      await launchUrl(Uri.parse(url),
                        mode: LaunchMode.externalApplication);
                    }
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
