part of '../main.dart';

List<MirrorItem> _dedupeItems(List<MirrorItem> source) {
  final seen = <String>{};
  final result = <MirrorItem>[];
  for (final item in source) {
    final key = '${item.kind}|${item.href}|${item.title}';
    if (seen.add(key)) result.add(item);
  }
  return result;
}

String _absoluteMusicUrl(String value) {
  final trimmed = value.trim();
  if (trimmed.startsWith('http://')) {
    return 'https://${trimmed.substring(7)}';
  }
  if (trimmed.startsWith('//')) return 'https:$trimmed';
  if (trimmed.startsWith('/')) return 'https://music.163.com$trimmed';
  return trimmed;
}

String _idFromMusicUrl(String value) {
  final match = RegExp(r'[?&]id=(\d+)').firstMatch(value);
  return match?.group(1) ?? '';
}

Map<String, dynamic> _mapOf(Object? value) {
  return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
}

List<Object?> _listOf(Object? value) {
  return value is List ? value : const [];
}

String _stringOf(Object? value) {
  if (value == null) return '';
  return value.toString().trim();
}

int _intOf(Object? value) {
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(_stringOf(value)) ?? 0;
}

double _doubleOf(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(_stringOf(value)) ?? 0;
}

String _formatSeconds(int value) {
  final normalized = value < 0 ? 0 : value;
  final minutes = normalized ~/ 60;
  final seconds = normalized % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

List<String> _lyricLines(String raw) {
  final lines = raw
      .split(RegExp(r'\r?\n'))
      .map((line) {
        return line
            .replaceAll(RegExp(r'\[[^\]]*\]'), '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
      })
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
  if (lines.isEmpty && raw.trim().isNotEmpty) {
    return [raw.trim()];
  }
  return lines;
}

List<LyricLine> _lyricTimedLines(String raw) {
  final result = <LyricLine>[];
  final pattern = RegExp(r'\[(\d+):(\d+(?:\.\d+)?)\]');
  for (final line in raw.split(RegExp(r'\r?\n'))) {
    final matches = pattern.allMatches(line).toList(growable: false);
    if (matches.isEmpty) continue;
    final text = line
        .replaceAll(pattern, '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (text.isEmpty) continue;
    for (final match in matches) {
      final minutes = int.tryParse(match.group(1) ?? '') ?? 0;
      final seconds = double.tryParse(match.group(2) ?? '') ?? 0;
      result.add(LyricLine(time: minutes * 60 + seconds, text: text));
    }
  }
  result.sort((a, b) => a.time.compareTo(b.time));
  return result;
}

Map<int, String> _lyricTimedMap(String raw) {
  final result = <int, String>{};
  final pattern = RegExp(r'\[(\d+):(\d+(?:\.\d+)?)\]');
  for (final line in raw.split(RegExp(r'\r?\n'))) {
    final matches = pattern.allMatches(line).toList(growable: false);
    if (matches.isEmpty) continue;
    final text = line
        .replaceAll(pattern, '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (text.isEmpty) continue;
    for (final match in matches) {
      final minutes = int.tryParse(match.group(1) ?? '') ?? 0;
      final seconds = double.tryParse(match.group(2) ?? '') ?? 0;
      result[((minutes * 60 + seconds) * 100).round()] = text;
    }
  }
  return result;
}

String? _translationAt(Map<int, String> translations, double time) {
  if (translations.isEmpty) return null;
  final key = (time * 100).round();
  final exact = translations[key];
  if (exact != null) return exact;
  for (var delta = 1; delta <= 35; delta++) {
    final before = translations[key - delta];
    if (before != null) return before;
    final after = translations[key + delta];
    if (after != null) return after;
  }
  return null;
}

List<String> _mergedLyricLines(String raw, String translated) {
  final original = _lyricTimedLines(raw);
  final translationMap = _lyricTimedMap(translated);
  if (original.isEmpty || translationMap.isEmpty) {
    return _lyricLines(raw);
  }
  return original
      .map((line) {
        final translation = _translationAt(translationMap, line.time);
        if (translation == null ||
            translation.isEmpty ||
            translation == line.text) {
          return line.text;
        }
        return '${line.text}\n$translation';
      })
      .toList(growable: false);
}

List<LyricLine> _mergedLyricTimedLines(String raw, String translated) {
  final original = _lyricTimedLines(raw);
  final translationMap = _lyricTimedMap(translated);
  if (original.isEmpty || translationMap.isEmpty) return original;
  return original
      .map((line) {
        final translation = _translationAt(translationMap, line.time);
        if (translation == null ||
            translation.isEmpty ||
            translation == line.text) {
          return line;
        }
        return LyricLine(time: line.time, text: '${line.text}\n$translation');
      })
      .toList(growable: false);
}

Uint8List? _bytesFromDataUrl(String source) {
  final comma = source.indexOf(',');
  if (comma < 0) return null;
  try {
    return base64Decode(source.substring(comma + 1));
  } catch (_) {
    return null;
  }
}
