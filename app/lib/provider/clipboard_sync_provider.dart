import 'dart:async';

import 'package:flutter/services.dart';
import 'package:localsend_app/provider/network/nearby_devices_provider.dart';
import 'package:localsend_app/provider/network/send_provider.dart';
import 'package:localsend_app/model/cross_file.dart';
import 'package:common/model/file_type.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';

final _logger = Logger('ClipboardSync');
const _uuid = Uuid();

class ClipboardSyncState {
  final bool enabled;
  final String? lastSyncedText;
  final DateTime? lastSyncedAt;

  const ClipboardSyncState({
    required this.enabled,
    this.lastSyncedText,
    this.lastSyncedAt,
  });

  ClipboardSyncState copyWith({
    bool? enabled,
    String? lastSyncedText,
    DateTime? lastSyncedAt,
  }) {
    return ClipboardSyncState(
      enabled: enabled ?? this.enabled,
      lastSyncedText: lastSyncedText ?? this.lastSyncedText,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}

final clipboardSyncProvider =
    NotifierProvider<ClipboardSyncNotifier, ClipboardSyncState>((ref) {
      return ClipboardSyncNotifier();
    });

class ClipboardSyncNotifier extends Notifier<ClipboardSyncState> {
  Timer? _pollTimer;
  static const _pollInterval = Duration(seconds: 2);

  @override
  ClipboardSyncState init() => const ClipboardSyncState(enabled: false);

  /// Enables clipboard monitoring and auto-send to all nearby devices.
  void enable() {
    if (state.enabled) return;
    state = state.copyWith(enabled: true);
    _startPolling();
    _logger.info('Clipboard sync enabled');
  }

  /// Disables clipboard monitoring.
  void disable() {
    _pollTimer?.cancel();
    _pollTimer = null;
    state = state.copyWith(enabled: false);
    _logger.info('Clipboard sync disabled');
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _checkClipboard());
  }

  Future<void> _checkClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();
      if (text == null || text.isEmpty) return;
      if (text == state.lastSyncedText) return;

      _logger.info('Clipboard changed, syncing to nearby devices');
      state = state.copyWith(
        lastSyncedText: text,
        lastSyncedAt: DateTime.now(),
      );

      await _sendToAllDevices(text);
    } catch (e) {
      _logger.warning('Clipboard sync error', e);
    }
  }

  Future<void> _sendToAllDevices(String text) async {
    final devices = ref.read(nearbyDevicesProvider).devices.values.toList();
    if (devices.isEmpty) return;

    final bytes = text.codeUnits;
    final file = CrossFile(
      name: 'clipboard_${_uuid.v4().substring(0, 8)}.txt',
      fileType: FileType.text,
      size: bytes.length,
      thumbnail: null,
      asset: null,
      path: null,
      bytes: bytes,
      lastModified: DateTime.now(),
      lastAccessed: DateTime.now(),
    );

    for (final device in devices) {
      try {
        await ref
            .notifier(sendProvider)
            .startSession(target: device, files: [file], background: true);
      } catch (e) {
        _logger.warning('Clipboard sync to ${device.alias} failed', e);
      }
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
