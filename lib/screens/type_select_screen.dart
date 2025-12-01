import 'package:flutter/material.dart';
import '../services/prefs.dart';
import '../models/watermark.dart';
import 'editor_screen.dart';
import 'package:file_selector/file_selector.dart' as fsel;

class TypeSelectScreen extends StatelessWidget {
  final List<fsel.XFile> files;
  const TypeSelectScreen({super.key, required this.files});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('选择水印类型')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Expanded(
              child: _TypeCard(
                title: 'EXIF 信息水印',
                subtitle: '将拍摄元数据叠加到图片底部白色区域',
                icon: Icons.description_outlined,
                onTap: () async {
                  final prefs = await AppPrefs.load();
                  // ignore: use_build_context_synchronously
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EditorScreen(
                        files: files,
                        type: WatermarkType.exif,
                        initialPrefs: prefs,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: _TypeCard(
                title: '占位类型',
                subtitle: '未来扩展用',
                icon: Icons.more_horiz,
                onTap: () {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  const _TypeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 48),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(subtitle, style: const TextStyle(color: Colors.black54)),
            ],
          ),
        ),
      ),
    );
  }
}

