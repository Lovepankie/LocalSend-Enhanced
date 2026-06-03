import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';

enum AuditDirection { sent, received }

class AuditEntry {
  final DateTime timestamp;
  final AuditDirection direction;
  final String peerAlias;
  final String fileName;
  final int fileSize;
  final bool success;
  final String? errorMessage;

  const AuditEntry({
    required this.timestamp,
    required this.direction,
    required this.peerAlias,
    required this.fileName,
    required this.fileSize,
    required this.success,
    this.errorMessage,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'direction': direction.name,
        'peerAlias': peerAlias,
        'fileName': fileName,
        'fileSize': fileSize,
        'success': success,
        if (errorMessage != null) 'errorMessage': errorMessage,
      };

  static AuditEntry fromJson(Map<String, dynamic> json) => AuditEntry(
        timestamp: DateTime.parse(json['timestamp'] as String),
        direction: AuditDirection.values.byName(json['direction'] as String),
        peerAlias: json['peerAlias'] as String,
        fileName: json['fileName'] as String,
        fileSize: json['fileSize'] as int,
        success: json['success'] as bool,
        errorMessage: json['errorMessage'] as String?,
      );
}

final auditLogProvider =
    NotifierProvider<AuditLogNotifier, List<AuditEntry>>((ref) {
  return AuditLogNotifier();
});

class AuditLogNotifier extends Notifier<List<AuditEntry>> {
  static const _maxEntries = 500;
  File? _logFile;

  @override
  List<AuditEntry> init() {
    _initFile();
    return [];
  }

  Future<void> _initFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _logFile = File('${dir.path}/localsend_audit.jsonl');
      final loaded = await _loadEntries();
      state = loaded;
    } catch (_) {}
  }

  Future<List<AuditEntry>> _loadEntries() async {
    final file = _logFile;
    if (file == null || !file.existsSync()) return [];
    final lines = await file.readAsLines();
    return lines
        .where((l) => l.trim().isNotEmpty)
        .map((l) {
          try {
            return AuditEntry.fromJson(jsonDecode(l) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<AuditEntry>()
        .toList();
  }

  /// Appends a new audit entry to the in-memory list and persists to disk.
  Future<void> log(AuditEntry entry) async {
    final updated = [...state, entry];
    // Trim to max entries to prevent unbounded growth
    final trimmed = updated.length > _maxEntries
        ? updated.sublist(updated.length - _maxEntries)
        : updated;
    state = trimmed;

    try {
      await _logFile?.writeAsString(
        '${jsonEncode(entry.toJson())}\n',
        mode: FileMode.append,
      );
    } catch (_) {}
  }

  Future<void> clearAll() async {
    state = [];
    try {
      await _logFile?.writeAsString('');
    } catch (_) {}
  }
}
