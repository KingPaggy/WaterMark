import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:exif/exif.dart' as exif;
import 'package:file_selector/file_selector.dart' as fsel;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;

import '../utils/exif_utils.dart';
import '../models/watermark.dart';
import '../painters/preview_painter.dart';
import '../services/prefs.dart';

class EditorScreen extends StatefulWidget {
  final List<fsel.XFile> files;
  final WatermarkType type;
  final Map<String, dynamic> initialPrefs;
  const EditorScreen({
    super.key,
    required this.files,
    required this.type,
    required this.initialPrefs,
  });
  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  int index = 0;
  Uint8List? imageBytes;
  ui.Image? uiImage;
  Map<String, String> exifMap = {};

  double bgHeightPercent = 0.2;
  String fontFamily = 'System';
  double fontSize = 18;
  Color fontColor = Colors.black;
  TextAlign alignment = TextAlign.left;
  double opacity = 0.85;
  List<String> exifKeys = List.of(defaultExifKeys);
  String author = '';
  ui.Image? logoImage;
  String? logoPath;

  bool loading = false;

  double _minFontForWidth(int w) => w / 3000.0;
  double _maxFontForWidth(int w) => w / 30.0;

  @override
  void initState() {
    super.initState();
    final p0 = widget.initialPrefs;
    bgHeightPercent = p0['bgHeightPercent'] as double;
    fontFamily = p0['fontFamily'] as String;
    fontSize = p0['fontSize'] as double;
    fontColor = p0['fontColor'] as Color;
    alignment = p0['alignment'] as TextAlign;
    opacity = p0['opacity'] as double;
    exifKeys = List<String>.from(p0['exifKeys'] as List<String>);
    author = (p0['author'] as String? ?? '');
    final lp = (p0['logoPath'] as String? ?? '');
    logoPath = lp.isEmpty ? null : lp;
    if (logoPath != null) {
      _loadLogo(logoPath!);
    }
    _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    setState(() => loading = true);
    try {
      final f = widget.files[index];
      final bytes = await f.readAsBytes();
      final imgObj = await decodeImage(bytes);
      final exifData = await readExif(bytes);
      setState(() {
        imageBytes = bytes;
        uiImage = imgObj;
        exifMap = exifData;
        if (uiImage != null) {
          final w = uiImage!.width;
          final minF = _minFontForWidth(w);
          final maxF = _maxFontForWidth(w);
          fontSize = fontSize.clamp(minF, maxF);
        }
      });
      final maker = exifData['Make'] ?? '';
      final up = maker.toUpperCase();
      if (up.contains('SONY')) {
        const sonyAssetPath = 'asset/Sony_logo.svg1024x.png';
        logoPath = sonyAssetPath;
        await _loadLogo(sonyAssetPath);
      } else if (up.contains('CANON')) {
        const canonAssetPath = 'asset/Canon_wordmark.svg1024x.png';
        logoPath = canonAssetPath;
        await _loadLogo(canonAssetPath);
      } else if (up.contains('NIKON')) {
        const nikonAssetPath = 'asset/Nikon_Logo.svg1024x.png';
        logoPath = nikonAssetPath;
        await _loadLogo(nikonAssetPath);
      }
    } finally {
      setState(() => loading = false);
    }
  }

  Future<ui.Image> decodeImage(Uint8List bytes) async {
    try {
      final c = Completer<ui.Image>();
      ui.decodeImageFromList(bytes, (i) => c.complete(i));
      return await c.future;
    } catch (_) {}
    final decoded = img.decodeImage(bytes);
    if (decoded != null) {
      final rgba = decoded.getBytes(order: img.ChannelOrder.rgba);
      final buffer = await ui.ImmutableBuffer.fromUint8List(Uint8List.fromList(rgba));
      final desc = ui.ImageDescriptor.raw(
        buffer,
        width: decoded.width,
        height: decoded.height,
        pixelFormat: ui.PixelFormat.rgba8888,
      );
      final codec = await desc.instantiateCodec();
      final frame = await codec.getNextFrame();
      return frame.image;
    }
    throw Exception('无法解码图片');
  }

  Future<void> _loadLogo(String path) async {
    try {
      Uint8List bytes;
      if (path.startsWith('asset/')) {
        final bd = await rootBundle.load(path);
        bytes = bd.buffer.asUint8List(bd.offsetInBytes, bd.lengthInBytes);
      } else {
        bytes = await fsel.XFile(path).readAsBytes();
      }
      final c = Completer<ui.Image>();
      ui.decodeImageFromList(bytes, (i) => c.complete(i));
      final img0 = await c.future;
      setState(() => logoImage = img0);
    } catch (_) {}
  }

  Future<Map<String, String>> readExif(Uint8List bytes) async {
    try {
      final data = await exif.readExifFromBytes(bytes);
      final Map<String, String> out = {};
      for (final entry in data.entries) {
        final key = entry.key;
        final val = entry.value.printable;
        final parts = key.split(' ');
        final canonical = parts.isNotEmpty ? parts.last : key;
        if (val.isNotEmpty && !out.containsKey(canonical)) {
          out[canonical] = val;
        }
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  Future<void> _savePrefs() async {
    await AppPrefs.save({
      'bgHeightPercent': bgHeightPercent,
      'fontFamily': fontFamily,
      'fontSize': fontSize,
      'fontColor': fontColor,
      'alignment': alignment,
      'opacity': opacity,
      'exifKeys': exifKeys,
      'author': author,
      'logoPath': logoPath,
    });
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.files[index];
    return Scaffold(
      appBar: AppBar(
        title: Text(p.basename(f.path)),
        actions: [
          IconButton(
            onPressed: () => _exportDialog(),
            icon: const Icon(Icons.save_alt),
            tooltip: '保存图片',
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.black12,
              child: loading || uiImage == null
                  ? const Center(child: CircularProgressIndicator())
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        return SizedBox(
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
                          child: CustomPaint(
                            isComplex: true,
                            willChange: true,
                            painter: PreviewPainter(
                              image: uiImage!,
                              exifMap: exifMap,
                              exifKeys: exifKeys,
                              bgHeightPercent: bgHeightPercent,
                              fontFamily: fontFamily,
                              fontSize: fontSize,
                              fontColor: fontColor,
                              alignment: alignment,
                              opacity: opacity,
                              logo: logoImage,
                              author: author,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          Container(
            width: 360,
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: Colors.grey.shade300)),
            ),
            child: _configPanel(),
          )
        ],
      ),
      bottomNavigationBar: _footerBar(),
    );
  }

  Widget _footerBar() {
    return BottomAppBar(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Text('${index + 1}/${widget.files.length}'),
            const Spacer(),
            IconButton(
              onPressed: index > 0
                  ? () async {
                      setState(() => index--);
                      await _loadCurrent();
                    }
                  : null,
              icon: const Icon(Icons.chevron_left),
              tooltip: '上一张',
            ),
            IconButton(
              onPressed: index < widget.files.length - 1
                  ? () async {
                      setState(() => index++);
                      await _loadCurrent();
                    }
                  : null,
              icon: const Icon(Icons.chevron_right),
              tooltip: '下一张',
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () async {
                await _savePrefs();
              },
              child: const Text('应用水印设置'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _configPanel() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('EXIF 信息水印配置', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: author,
          decoration: const InputDecoration(labelText: '作者'),
          onChanged: (v) => setState(() => author = v),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Text(logoPath ?? '未选择 PNG Logo')),
          TextButton(
            onPressed: () async {
              final file = await fsel.openFile(
                acceptedTypeGroups: const [fsel.XTypeGroup(extensions: ['png'])],
              );
              if (file != null) {
                logoPath = file.path;
                await _loadLogo(file.path);
              }
            },
            child: const Text('选择 PNG Logo'),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          const Text('背景高度'),
          Expanded(
            child: Slider(
              value: bgHeightPercent,
              min: 0.1,
              max: 0.5,
              divisions: 40,
              label: '${(bgHeightPercent * 100).round()}%',
              onChanged: (v) => setState(() => bgHeightPercent = v),
            ),
          ),
        ]),
        Row(children: [
          const Text('透明度'),
          Expanded(
            child: Slider(
              value: opacity,
              min: 0.2,
              max: 1.0,
              divisions: 40,
              label: '${(opacity * 100).round()}%',
              onChanged: (v) => setState(() => opacity = v),
            ),
          ),
        ]),
        Row(children: [
          const Text('字体大小'),
          Expanded(
            child: Slider(
              value: fontSize,
              min: uiImage != null ? _minFontForWidth(uiImage!.width) : 12,
              max: uiImage != null ? _maxFontForWidth(uiImage!.width) : 36,
              label: fontSize.toStringAsFixed(1),
              onChanged: (v) => setState(() => fontSize = v),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: fontFamily,
          decoration: const InputDecoration(labelText: '字体'),
          items: const [
            DropdownMenuItem(value: 'System', child: Text('System')),
            DropdownMenuItem(value: 'Times', child: Text('Times New Roman')),
            DropdownMenuItem(value: 'Helvetica', child: Text('Helvetica Neue')),
            DropdownMenuItem(value: 'Menlo', child: Text('Menlo')),
          ],
          onChanged: (v) => setState(() => fontFamily = v ?? 'System'),
        ),
        const SizedBox(height: 8),
        Row(children: [
          const Text('文字颜色'),
          const SizedBox(width: 12),
          _colorDot(Colors.black),
          _colorDot(Colors.white),
          _colorDot(Colors.blueGrey),
          _colorDot(Colors.redAccent),
          _colorDot(Colors.green),
        ]),
        const SizedBox(height: 8),
        DropdownButtonFormField<TextAlign>(
          initialValue: alignment,
          decoration: const InputDecoration(labelText: '对齐方式'),
          items: const [
            DropdownMenuItem(value: TextAlign.left, child: Text('左对齐')),
            DropdownMenuItem(value: TextAlign.center, child: Text('居中')),
            DropdownMenuItem(value: TextAlign.right, child: Text('右对齐')),
          ],
          onChanged: (v) => setState(() => alignment = v ?? TextAlign.left),
        ),
        const SizedBox(height: 16),
        const Text('显示的 EXIF 字段'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: defaultExifKeys
              .map(
                (k) => FilterChip(
                  label: Text(k),
                  selected: exifKeys.contains(k),
                  onSelected: (sel) {
                    setState(() {
                      if (sel) {
                        exifKeys.add(k);
                      } else {
                        exifKeys.remove(k);
                      }
                    });
                  },
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () async {
            await _savePrefs();
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('设置已保存')),
            );
          },
          icon: const Icon(Icons.check),
          label: const Text('应用水印'),
        ),
      ],
    );
  }

  Widget _colorDot(Color c) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => fontColor = c),
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: c,
            border: Border.all(color: Colors.black12),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Future<void> _exportDialog() async {
    final format = await showDialog<String>(
      context: context,
      builder: (ctx) {
        String fmt = 'jpeg';
        double quality = 90;
        return AlertDialog(
          title: const Text('导出选项'),
          content: StatefulBuilder(builder: (ctx, setS) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: fmt,
                  items: const [
                    DropdownMenuItem(value: 'jpeg', child: Text('JPEG')),
                    DropdownMenuItem(value: 'png', child: Text('PNG')),
                  ],
                  onChanged: (v) => setS(() => fmt = v ?? 'jpeg'),
                  decoration: const InputDecoration(labelText: '格式'),
                ),
                if (fmt == 'jpeg')
                  Row(children: [
                    const Text('质量'),
                    Expanded(
                      child: Slider(
                        value: quality,
                        min: 50,
                        max: 100,
                        divisions: 50,
                        label: quality.toStringAsFixed(0),
                        onChanged: (v) => setS(() => quality = v),
                      ),
                    ),
                  ]),
              ],
            );
          }),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(ctx, fmt), child: const Text('导出')),
          ],
        );
      },
    );
    if (format == null) return;
    await _export(format);
  }

  Future<void> _export(String format) async {
    if (uiImage == null || imageBytes == null) return;
    final composed = await _compose(uiImage!, exifMap);
    if (format == 'png') {
      final pngBytes = await composed.toByteData(format: ui.ImageByteFormat.png);
      if (pngBytes == null) return;
      final name = p.setExtension(p.basename(widget.files[index].path), '.png');
      final loc = await fsel.getSaveLocation(
        suggestedName: name,
        acceptedTypeGroups: [const fsel.XTypeGroup(extensions: ['png'])],
      );
      if (loc == null) return;
      final png = Uint8List.view(
        pngBytes.buffer,
        pngBytes.offsetInBytes,
        pngBytes.lengthInBytes,
      );
      final xf = fsel.XFile.fromData(
        png,
        name: name,
        mimeType: 'image/png',
      );
      await xf.saveTo(loc.path);
    } else {
      final raw = await composed.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (raw == null) return;
      final rgba = Uint8List.view(raw.buffer, raw.offsetInBytes, raw.lengthInBytes);
      final im = img.Image.fromBytes(
        width: composed.width,
        height: composed.height,
        bytes: Uint8List.fromList(rgba).buffer,
        order: img.ChannelOrder.rgba,
      );
      var jpg = img.encodeJpg(im, quality: 90);
      try {
        final original = img.decodeJpg(imageBytes!);
        final exifData = original?.exif;
        if (exifData != null) {
          final injected = img.injectJpgExif(Uint8List.fromList(jpg), exifData);
          if (injected != null) {
            jpg = injected;
          }
        }
      } catch (_) {}
      final name = p.setExtension(p.basename(widget.files[index].path), '.jpg');
      final loc = await fsel.getSaveLocation(
        suggestedName: name,
        acceptedTypeGroups: [const fsel.XTypeGroup(extensions: ['jpg', 'jpeg'])],
      );
      if (loc == null) return;
      final xf = fsel.XFile.fromData(
        Uint8List.fromList(jpg),
        name: name,
        mimeType: 'image/jpeg',
      );
      await xf.saveTo(loc.path);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存')));
  }

  Future<ui.Image> _compose(ui.Image base, Map<String, String> exifVals) async {
    final recorder = ui.PictureRecorder();
    final w = base.width.toDouble();
    final h = base.height.toDouble();
    final totalH = h * (1 + bgHeightPercent);
    final canvas = Canvas(recorder);
    canvas.drawImage(base, Offset.zero, Paint());
    final bgH = h * bgHeightPercent;
    final bgRect = Rect.fromLTWH(0, h, w, bgH);
    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;
    canvas.drawRect(bgRect, bgPaint);

    final leftW = bgH.clamp(0, w * 0.3);
    if (logoImage != null) {
      final lW = logoImage!.width.toDouble();
      final lH = logoImage!.height.toDouble();
      final maxSide = leftW.toDouble() * 0.8;
      final ls = (maxSide / lW).clamp(0.0, double.infinity);
      final lsH = (maxSide / lH).clamp(0.0, double.infinity);
      final scale = lsH < ls ? lsH : ls;
      final dw = lW * scale;
      final dh = lH * scale;
      final ldx = bgRect.left + (leftW.toDouble() - dw) / 2;
      final ldy = bgRect.top + (bgH - dh) / 2;
      final ldest = Rect.fromLTWH(ldx, ldy, dw, dh);
      final lsrc = Rect.fromLTWH(0, 0, lW, lH);
      final lpaint = Paint()..filterQuality = FilterQuality.high..isAntiAlias = true;
      canvas.drawImageRect(logoImage!, lsrc, ldest, lpaint);
    }

    final rightStart = bgRect.left + leftW.toDouble();
    final rightW = w - leftW.toDouble();
    // formatting helpers are centralized in ExifUtils

    final lines = ExifUtils.twoLines(exifVals);
    final topText = lines['top'] ?? '';
    final bottomText = lines['bottom'] ?? '';
    ui.Paragraph buildPara(String t, double width) {
      final pb = ui.ParagraphBuilder(
        ui.ParagraphStyle(
          textAlign: TextAlign.left,
          fontSize: fontSize,
          fontFamily: fontFamily != 'System' ? fontFamily : null,
        ),
      )..pushStyle(ui.TextStyle(color: fontColor));
      pb.addText(t);
      final p = pb.build();
      p.layout(ui.ParagraphConstraints(width: width));
      return p;
    }
    final topP = buildPara(topText, rightW - 40);
    final botP = buildPara(bottomText, rightW - 40);
    final midY = h + bgH / 2;
    final topY = midY - (topP.height + 10);
    final botY = midY + 10;
    final textX = rightStart + 20;
    if (topText.isNotEmpty) {
      canvas.drawParagraph(topP, Offset(textX, topY));
    }
    if (bottomText.isNotEmpty) {
      canvas.drawParagraph(botP, Offset(textX, botY));
    }
    if (author.isNotEmpty) {
      final apb = ui.ParagraphBuilder(
        ui.ParagraphStyle(
          textAlign: TextAlign.center,
          fontSize: fontSize,
          fontFamily: fontFamily != 'System' ? fontFamily : null,
        ),
      )..pushStyle(ui.TextStyle(color: fontColor));
      apb.addText(author);
      final ap = apb.build();
      ap.layout(ui.ParagraphConstraints(width: w));
      final ax = (w - ap.maxIntrinsicWidth) / 2;
      final ay = h + (bgH - ap.height) / 2;
      canvas.drawParagraph(ap, Offset(ax, ay));
    }

    final pic = recorder.endRecording();
    return pic.toImage(w.toInt(), totalH.toInt());
  }
}
