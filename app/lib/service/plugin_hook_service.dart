import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

final _logger = Logger('PluginHook');

/// A configured hook that fires when a file is received.
class ReceiveHook {
  final String id;
  final String name;
  final HookType type;
  final String target; // shell command or webhook URL

  const ReceiveHook({
    required this.id,
    required this.name,
    required this.type,
    required this.target,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'target': target,
      };

  static ReceiveHook fromJson(Map<String, dynamic> json) => ReceiveHook(
        id: json['id'] as String,
        name: json['name'] as String,
        type: HookType.values.byName(json['type'] as String),
        target: json['target'] as String,
      );
}

enum HookType { shellCommand, webhook }

class HookPayload {
  final String fileName;
  final String? filePath;
  final int fileSize;
  final String senderAlias;
  final DateTime timestamp;

  const HookPayload({
    required this.fileName,
    this.filePath,
    required this.fileSize,
    required this.senderAlias,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'fileName': fileName,
        'filePath': filePath,
        'fileSize': fileSize,
        'senderAlias': senderAlias,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Fires configured hooks when a file is received.
/// Hooks run asynchronously and failures are logged, not surfaced to UI.
class PluginHookService {
  final List<ReceiveHook> hooks;

  const PluginHookService({required this.hooks});

  Future<void> fireOnReceive(HookPayload payload) async {
    for (final hook in hooks) {
      _fire(hook, payload);
    }
  }

  void _fire(ReceiveHook hook, HookPayload payload) {
    switch (hook.type) {
      case HookType.shellCommand:
        _runShell(hook, payload);
      case HookType.webhook:
        _postWebhook(hook, payload);
    }
  }

  Future<void> _runShell(ReceiveHook hook, HookPayload payload) async {
    final env = {
      'LS_FILE_NAME': payload.fileName,
      'LS_FILE_PATH': payload.filePath ?? '',
      'LS_FILE_SIZE': '${payload.fileSize}',
      'LS_SENDER': payload.senderAlias,
      'LS_TIMESTAMP': payload.timestamp.toIso8601String(),
    };

    _logger.info('Running hook "${hook.name}": ${hook.target}');
    try {
      final result = await Process.run(
        '/bin/sh',
        ['-c', hook.target],
        environment: {...Platform.environment, ...env},
      );
      if (result.exitCode != 0) {
        _logger.warning(
          'Hook "${hook.name}" exited with ${result.exitCode}: ${result.stderr}',
        );
      }
    } catch (e) {
      _logger.warning('Hook "${hook.name}" failed to run', e);
    }
  }

  Future<void> _postWebhook(ReceiveHook hook, HookPayload payload) async {
    _logger.info('Calling webhook "${hook.name}": ${hook.target}');
    try {
      final client = HttpClient();
      final req = await client.postUrl(Uri.parse(hook.target));
      req.headers
        ..contentType = ContentType.json
        ..set('User-Agent', 'LocalSend-Enhanced-Hook/1.0');
      req.write(jsonEncode(payload.toJson()));
      final resp = await req.close();
      await resp.drain<void>();
      _logger.info('Webhook "${hook.name}" responded: ${resp.statusCode}');
      client.close();
    } catch (e) {
      _logger.warning('Webhook "${hook.name}" failed', e);
    }
  }
}
