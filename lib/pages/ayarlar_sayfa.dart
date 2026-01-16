import 'package:flutter/material.dart';

class AyarlarSayfa extends StatelessWidget {
  const AyarlarSayfa({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B2741),
      appBar: AppBar(
        title: const Text('Ayarlar'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const ListTile(
            leading: Icon(Icons.notifications, color: Colors.white),
            title: Text('Bildirimler', style: TextStyle(color: Colors.white)),
          ),
          const Divider(color: Colors.white24),
          const ListTile(
            leading: Icon(Icons.palette, color: Colors.white),
            title: Text('Tema', style: TextStyle(color: Colors.white)),
          ),
          const Divider(color: Colors.white24),
          ListTile(
            leading: const Icon(Icons.info, color: Colors.white),
            title: const Text('Hakkında', style: TextStyle(color: Colors.white)),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Huzur Vakti',
                applicationVersion: '1.0.0',
              );
            },
          ),
        ],
      ),
    );
  }
}
