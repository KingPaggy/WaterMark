import 'dart:core';
import 'dart:typed_data';
import 'package:exif/exif.dart';

class ExifUtils {
  static Future<Map<String, String>> readExif(Uint8List bytes) async {
    try {
      final data = await readExifFromBytes(bytes);
      final Map<String, String> out = {};
      for (final entry in data.entries) {
        final key = entry.key;
        final val = entry.value.printable;
        // Simplify keys: 'Image Model' -> 'Model'
        final parts = key.split(' ');
        final canonical = parts.isNotEmpty ? parts.last : key;
        if (val.isNotEmpty && !out.containsKey(canonical)) {
          out[canonical] = val;
        }
      }
      return out;
    } catch (e) {
      // ignore error
      return {};
    }
  }

  static String? pick(Map<String, String> exif, List<String> keys) {
    for (final k in keys) {
      final v = exif[k];
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  static final RegExp _stripPointZero = RegExp(r'\.0$');

  static String formatFocal(String? v) {
    if (v == null) return '';
    var t = v.trim();
    if (t.contains('/')) {
      final parts = t.split('/');
      final a = double.tryParse(parts[0]);
      final b = double.tryParse(parts.length > 1 ? parts[1] : '1') ?? 1.0;
      if (a != null && b != 0) {
        final num = (a / b);
        t = num.toStringAsFixed(1).replaceAll(_stripPointZero, '');
      }
    }
    if (!t.toLowerCase().contains('mm')) t = '$t mm';
    return t;
  }

  static String formatISO(String? v) {
    return v == null ? '' : 'ISO ${v.trim()}';
  }

  static String formatFNumber(String? v) {
    if (v == null) return '';
    var t = v.trim();
    if (t.contains('/')) {
      final parts = t.split('/');
      final a = double.tryParse(parts[0]);
      final b = double.tryParse(parts.length > 1 ? parts[1] : '1') ?? 1.0;
      if (a != null && b != 0) {
        final num = (a / b);
        t = num.toStringAsFixed(1).replaceAll(_stripPointZero, '');
      }
    }
    return 'f/$t';
  }

  static Map<String, String> twoLines(Map<String, String> exif) {
    // final make = pick(exif, ['Make']);
    final model = pick(exif, ['Model']);
    final lens = pick(exif, ['LensModel']);
    final focal = formatFocal(pick(exif, ['FocalLength']));
    final expTime = pick(exif, ['ExposureTime']);
    final iso = formatISO(pick(exif, ['ISOSpeedRatings', 'ISOSpeedRating']));
    final fnum = formatFNumber(pick(exif, ['FNumber']));
    final topParts = [
      model,
      lens,
    ].where((e) => e != null && e.isNotEmpty).cast<String>().toList();
    final bottomParts = [
      focal,
      expTime ?? '',
      iso,
      fnum,
    ].where((e) => e.isNotEmpty).toList();
    return {'top': topParts.join(' • '), 'bottom': bottomParts.join(' • ')};
  }
}
