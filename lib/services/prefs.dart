import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPrefs {
  static const _bgHeightKey = 'bgHeightPercent';
  static const _fontFamilyKey = 'fontFamily';
  static const _fontSizeKey = 'fontSize';
  static const _fontColorKey = 'fontColor';
  static const _alignmentKey = 'alignment';
  static const _opacityKey = 'opacity';
  static const _exifKeysKey = 'exifKeys';
  static const _authorKey = 'author';
  static const _logoPathKey = 'logoPath';

  static Future<void> save(Map<String, dynamic> v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setDouble(_bgHeightKey, (v['bgHeightPercent'] as double));
    await sp.setString(_fontFamilyKey, (v['fontFamily'] as String));
    await sp.setDouble(_fontSizeKey, (v['fontSize'] as double));
    await sp.setInt(_fontColorKey, (v['fontColor'] as Color).toARGB32());
    await sp.setString(_alignmentKey, (v['alignment'] as TextAlign).name);
    await sp.setDouble(_opacityKey, (v['opacity'] as double));
    await sp.setStringList(_exifKeysKey, (v['exifKeys'] as List<String>));
    await sp.setString(_authorKey, (v['author'] as String));
    await sp.setString(_logoPathKey, (v['logoPath'] as String? ?? ''));
  }

  static Future<Map<String, dynamic>> load() async {
    final sp = await SharedPreferences.getInstance();
    return {
      'bgHeightPercent': sp.getDouble(_bgHeightKey) ?? 0.2,
      'fontFamily': sp.getString(_fontFamilyKey) ?? 'System',
      'fontSize': sp.getDouble(_fontSizeKey) ?? 18,
      'fontColor': Color(sp.getInt(_fontColorKey) ?? Colors.black.toARGB32()),
      'alignment': TextAlign.values.firstWhere(
        (e) => e.name == (sp.getString(_alignmentKey) ?? TextAlign.left.name),
        orElse: () => TextAlign.left,
      ),
      'opacity': sp.getDouble(_opacityKey) ?? 0.85,
      'exifKeys': sp.getStringList(_exifKeysKey) ?? defaultExifKeys,
      'author': sp.getString(_authorKey) ?? '',
      'logoPath': sp.getString(_logoPathKey) ?? '',
    };
  }
}

const defaultExifKeys = <String>[
  'DateTimeOriginal',
  'Make',
  'Model',
  'LensModel',
  'FNumber',
  'ExposureTime',
  'ISOSpeedRatings',
  'FocalLength',
  'GPSLatitude',
  'GPSLongitude',
];
