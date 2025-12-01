import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../utils/exif_utils.dart';

class PreviewPainter extends CustomPainter {
  final ui.Image image;
  final Map<String, String> exifMap;
  final List<String> exifKeys;
  final double bgHeightPercent;
  final String fontFamily;
  final double fontSize;
  final Color fontColor;
  final TextAlign alignment;
  final double opacity;
  final ui.Image? logo;
  final String author;
  PreviewPainter({
    required this.image,
    required this.exifMap,
    required this.exifKeys,
    required this.bgHeightPercent,
    required this.fontFamily,
    required this.fontSize,
    required this.fontColor,
    required this.alignment,
    required this.opacity,
    this.logo,
    this.author = '',
  });
  @override
  void paint(Canvas canvas, Size size) {
    final imgW = image.width.toDouble();
    final imgH = image.height.toDouble();
    final viewW = size.width;
    final viewH = size.height;

    final compH = imgH * (1 + bgHeightPercent);
    final sW = (viewW / imgW).clamp(0.0, double.infinity).toDouble();
    final sH = (viewH / compH).clamp(0.0, double.infinity).toDouble();
    var s = sH < sW ? sH : sW;
    if (s > 1) s = 1;

    final destW = imgW * s;
    final destH = imgH * s;
    final bgH = destH * bgHeightPercent;
    final dx = (viewW - destW) / 2;
    final dy = (viewH - (destH + bgH)) / 2;
    final dest = Rect.fromLTWH(dx, dy, destW, destH);
    final src = Rect.fromLTWH(0, 0, imgW, imgH);

    final paint = Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high;
    canvas.drawImageRect(image, src, dest, paint);

    final bgRect = Rect.fromLTWH(dest.left, dest.bottom, destW, bgH);
    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;
    canvas.drawRect(bgRect, bgPaint);

    final leftW = bgRect.height.clamp(0, bgRect.width * 0.3);
    if (logo != null) {
      final lw = leftW.toDouble();
      final maxSide = lw * 0.8;
      final lW = logo!.width.toDouble();
      final lH = logo!.height.toDouble();
      final ls = (maxSide / lW).clamp(0.0, double.infinity);
      final lsH = (maxSide / lH).clamp(0.0, double.infinity);
      final lscale = lsH < ls ? lsH : ls;
      final dw = lW * lscale;
      final dh = lH * lscale;
      final ldx = bgRect.left + (lw - dw) / 2;
      final ldy = bgRect.top + (bgRect.height - dh) / 2;
      final ldest = Rect.fromLTWH(ldx, ldy, dw, dh);
      final lsrc = Rect.fromLTWH(0, 0, lW, lH);
      final lpaint = Paint()..filterQuality = FilterQuality.high..isAntiAlias = true;
      canvas.drawImageRect(logo!, lsrc, ldest, lpaint);
    }

    final rightStart = bgRect.left + leftW.toDouble();
    final rightW = bgRect.width - leftW.toDouble();

    // formatting helpers are centralized in ExifUtils

    final lines = ExifUtils.twoLines(exifMap);
    final topText = lines['top'] ?? '';
    final bottomText = lines['bottom'] ?? '';

    ui.Paragraph buildPara(String t, double w) {
      final pb = ui.ParagraphBuilder(
        ui.ParagraphStyle(
          textAlign: TextAlign.left,
          fontSize: fontSize * s,
          fontFamily: fontFamily != 'System' ? fontFamily : null,
        ),
      )..pushStyle(ui.TextStyle(color: fontColor));
      pb.addText(t);
      final p = pb.build();
      p.layout(ui.ParagraphConstraints(width: w));
      return p;
    }
    final topP = buildPara(topText, rightW - 40 * s);
    final botP = buildPara(bottomText, rightW - 40 * s);
    final midY = bgRect.top + bgRect.height / 2;
    final topY = midY - (topP.height + 10 * s);
    final botY = midY + 10 * s;
    final textX = rightStart + 20 * s;
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
          fontSize: fontSize * s,
          fontFamily: fontFamily != 'System' ? fontFamily : null,
        ),
      )..pushStyle(ui.TextStyle(color: fontColor));
      apb.addText(author);
      final ap = apb.build();
      ap.layout(ui.ParagraphConstraints(width: bgRect.width));
      final ax = bgRect.left + (bgRect.width - ap.maxIntrinsicWidth) / 2;
      final ay = bgRect.top + (bgRect.height - ap.height) / 2;
      canvas.drawParagraph(ap, Offset(ax, ay));
    }
  }
  @override
  bool shouldRepaint(covariant PreviewPainter oldDelegate) {
    return oldDelegate.bgHeightPercent != bgHeightPercent ||
        oldDelegate.fontFamily != fontFamily ||
        oldDelegate.fontSize != fontSize ||
        oldDelegate.fontColor != fontColor ||
        oldDelegate.alignment != alignment ||
        oldDelegate.opacity != opacity ||
        oldDelegate.exifMap != exifMap ||
        oldDelegate.exifKeys != exifKeys ||
        oldDelegate.image != image;
  }
}
