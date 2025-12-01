import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart' as fsel;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'type_select_screen.dart';

class EntryScreen extends StatefulWidget {
  const EntryScreen({super.key});
  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  List<fsel.XFile> files = [];
  bool isDragging = false;

  Future<void> _pickFiles() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowMultiple: true,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'heic', 'tif', 'tiff'],
    );
    if (res != null) {
      setState(() {
        files = res.files
            .where((f) => (f.path ?? '').isNotEmpty)
            .map((f) => fsel.XFile(f.path!))
            .toList();
      });
      if (files.isNotEmpty) {
        _goNext();
      }
    }
  }

  void _goNext() {
    if (files.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TypeSelectScreen(files: files),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('选择图片')),
      body: DropTarget(
        onDragEntered: (_) => setState(() => isDragging = true),
        onDragExited: (_) => setState(() => isDragging = false),
        onDragDone: (detail) {
          setState(() {
            files = detail.files
                .where((f) => _isSupported(f.path))
                .map((f) => fsel.XFile(f.path))
                .toList();
          });
          if (files.isNotEmpty) {
            _goNext();
          }
        },
        child: Center(
          child: Container(
            width: 560,
            height: 320,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDragging ? Colors.blue : Colors.grey,
                width: 2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_upload_outlined,
                    size: 64, color: isDragging ? Colors.blue : Colors.grey),
                const SizedBox(height: 12),
                const Text('拖放图片到此处，或点击下方按钮浏览'),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _pickFiles,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('浏览选择'),
                ),
                const SizedBox(height: 12),
                Text(
                  files.isEmpty
                      ? '支持 JPEG/PNG/HEIC'
                      : '已选择 ${files.length} 张',
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: files.isEmpty ? null : _goNext,
                  child: const Text('下一步'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isSupported(String path) {
    final ext = p.extension(path).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.heic', '.tif', '.tiff'].contains(ext);
  }
}
