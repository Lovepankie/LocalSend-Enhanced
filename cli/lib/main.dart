import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:common/constants.dart';
import 'package:common/model/device.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
    ..addFlag('json', abbr: 'j', negatable: false, help: 'Output as JSON lines')
    ..addFlag('verbose', abbr: 'v', negatable: false, help: 'Verbose logging')
    ..addSeparator('Commands:')
    ..addFlag('scan', negatable: false, help: 'Scan for nearby LocalSend devices')
    ..addFlag('receive', abbr: 'r', negatable: false, help: 'Start headless receive mode')
    ..addFlag('send', abbr: 's', negatable: false, help: 'Send files to a device')
    ..addSeparator('Options:')
    ..addOption('target', abbr: 't', help: 'Target IP address (required for --send)')
    ..addOption('port', abbr: 'p', defaultsTo: '$defaultPort', help: 'Target port')
    ..addOption('output', abbr: 'o', defaultsTo: '.', help: 'Output directory for received files');

  final ArgResults results;
  try {
    results = parser.parse(arguments);
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}');
    _printUsage(parser);
    exit(1);
  }

  if (results['help'] as bool) {
    _printUsage(parser);
    return;
  }

  final jsonMode = results['json'] as bool;
  final cli = LocalSendCli(jsonOutput: jsonMode);

  if (results['scan'] as bool) {
    await cli.scan();
    return;
  }

  if (results['receive'] as bool) {
    final outputDir = results['output'] as String;
    await cli.receive(outputDir: outputDir);
    return;
  }

  if (results['send'] as bool) {
    final target = results['target'] as String?;
    final portStr = results['port'] as String;
    final port = int.tryParse(portStr) ?? defaultPort;
    final files = results.rest;

    if (target == null) {
      stderr.writeln('Error: --target is required for send');
      exit(1);
    }
    if (files.isEmpty) {
      stderr.writeln('Error: specify one or more file paths after options');
      exit(1);
    }
    await cli.send(targetIp: target, port: port, filePaths: files);
    return;
  }

  _printUsage(parser);
}

void _printUsage(ArgParser parser) {
  print('LocalSend Enhanced CLI — send and receive files locally');
  print('');
  print('Usage: localsend [options] [files...]');
  print('');
  print(parser.usage);
  print('');
  print('Examples:');
  print('  localsend --scan');
  print('  localsend --receive -o ~/Downloads');
  print('  localsend --send -t 192.168.1.5 file.txt photo.jpg');
  print('  localsend --send -t 192.168.1.5 --json *.pdf');
}

class LocalSendCli {
  final bool jsonOutput;

  LocalSendCli({required this.jsonOutput});

  void _log(String level, String message, [Map<String, dynamic>? extra]) {
    if (jsonOutput) {
      final obj = <String, dynamic>{
        'timestamp': DateTime.now().toIso8601String(),
        'level': level,
        'message': message,
        if (extra != null) ...extra,
      };
      print(jsonEncode(obj));
    } else {
      final prefix = switch (level) {
        'info' => '  ',
        'ok' => '✓ ',
        'error' => '✗ ',
        'warn' => '! ',
        _ => '  ',
      };
      print('$prefix$message');
    }
  }

  void _progress(String fileName, int sent, int total) {
    if (jsonOutput) {
      print(jsonEncode({
        'type': 'progress',
        'file': fileName,
        'sent': sent,
        'total': total,
        'percent': total > 0 ? (sent / total * 100).toStringAsFixed(1) : '0',
      }));
    } else {
      final pct = total > 0 ? (sent / total * 100).round() : 0;
      final bar = '█' * (pct ~/ 5) + '░' * (20 - pct ~/ 5);
      stdout.write('\r  [$bar] ${pct.toString().padLeft(3)}% — $fileName   ');
      if (sent >= total) print('');
    }
  }

  Future<void> scan() async {
    _log('info', 'Scanning for LocalSend devices on local network…');

    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );

    final found = <Map<String, dynamic>>[];

    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        final parts = addr.address.split('.');
        if (parts.length != 4) continue;
        final subnet = parts.sublist(0, 3).join('.');

        _log('info', 'Scanning $subnet.0/24…');

        final futures = List.generate(254, (i) async {
          final ip = '$subnet.${i + 1}';
          try {
            final client = HttpClient()
              ..connectionTimeout = const Duration(milliseconds: 300);
            final req = await client
                .getUrl(Uri.parse('http://$ip:$defaultPort/api/localsend/v2/info'))
                .timeout(const Duration(milliseconds: 600));
            final resp = await req.close().timeout(const Duration(milliseconds: 600));
            if (resp.statusCode == 200) {
              final body = await utf8.decoder.bind(resp).join();
              final json = jsonDecode(body) as Map<String, dynamic>;
              return {
                'ip': ip,
                'alias': json['alias'] ?? ip,
                'version': json['version'] ?? fallbackProtocolVersion,
                'port': json['port'] ?? defaultPort,
                'deviceModel': json['deviceModel'],
                'deviceType': json['deviceType'],
              };
            }
          } catch (_) {}
          return null;
        });

        final results = await Future.wait(futures);
        found.addAll(results.whereType<Map<String, dynamic>>());
      }
    }

    if (found.isEmpty) {
      _log('warn', 'No LocalSend devices found');
      return;
    }

    if (jsonOutput) {
      for (final d in found) {
        print(jsonEncode({'type': 'device', ...d}));
      }
    } else {
      print('');
      print('Found ${found.length} device(s):');
      for (final d in found) {
        print('  • ${d['alias']} (${d['ip']}:${d['port']}) — ${d['deviceModel'] ?? 'unknown'}');
      }
    }
  }

  Future<void> receive({required String outputDir}) async {
    final dir = Directory(outputDir);
    if (!dir.existsSync()) dir.createSync(recursive: true);

    _log('info', 'Listening on port $defaultPort');
    _log('info', 'Saving to: ${dir.absolute.path}');
    _log('info', 'Press Ctrl+C to stop');

    final server = await HttpServer.bind(InternetAddress.anyIPv4, defaultPort);

    await for (final request in server) {
      _handleRequest(request, dir);
    }
  }

  Future<void> _handleRequest(HttpRequest request, Directory outputDir) async {
    final uri = request.uri;

    if (uri.path.endsWith('/info') && request.method == 'GET') {
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          'alias': 'LocalSend-CLI',
          'version': protocolVersion,
          'deviceModel': 'CLI',
          'deviceType': 'headless',
          'fingerprint': 'cli-fingerprint',
          'port': defaultPort,
          'protocol': 'http',
          'download': false,
          'announce': false,
        }));
      await request.response.close();
      return;
    }

    if (uri.path.endsWith('/prepare-upload') && request.method == 'POST') {
      final body = await utf8.decoder.bind(request).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final files = (json['files'] as Map<String, dynamic>?) ?? {};
      final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
      final tokens = {for (final k in files.keys) k: 'token-$k'};
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'sessionId': sessionId, 'files': tokens}));
      await request.response.close();
      _log('info', 'Incoming transfer: ${files.length} file(s)');
      return;
    }

    if (uri.path.endsWith('/upload') && request.method == 'POST') {
      final fileName = uri.queryParameters['fileName'] ?? 'received_${DateTime.now().millisecondsSinceEpoch}';
      final outFile = File(p.join(outputDir.path, p.basename(fileName)));
      final sink = outFile.openWrite();
      var received = 0;
      final total = int.tryParse(request.headers.value('content-length') ?? '') ?? 0;

      await for (final chunk in request) {
        sink.add(chunk);
        received += chunk.length;
        _progress(fileName, received, total);
      }
      await sink.close();

      request.response..statusCode = 200;
      await request.response.close();
      _log('ok', 'Saved: ${outFile.path} (${_formatSize(received)})',
          {'file': outFile.path, 'size': received});
      return;
    }

    if (uri.path.endsWith('/cancel')) {
      request.response..statusCode = 200;
      await request.response.close();
      return;
    }

    request.response..statusCode = 404;
    await request.response.close();
  }

  Future<void> send({
    required String targetIp,
    required int port,
    required List<String> filePaths,
  }) async {
    _log('info', 'Connecting to $targetIp:$port');

    final client = HttpClient();

    final fileEntries = <String, File>{};
    final fileMeta = <String, dynamic>{};
    var idx = 0;

    for (final path in filePaths) {
      final file = File(path);
      if (!file.existsSync()) {
        _log('error', 'Not found: $path');
        continue;
      }
      final id = 'f${idx++}';
      fileEntries[id] = file;
      fileMeta[id] = {
        'id': id,
        'fileName': p.basename(file.path),
        'size': file.lengthSync(),
        'fileType': 'other',
        'preview': null,
        'metadata': null,
      };
    }

    if (fileEntries.isEmpty) {
      _log('error', 'No valid files to send');
      exit(1);
    }

    try {
      // Prepare upload
      final prepReq = await client.postUrl(
        Uri.parse('http://$targetIp:$port/api/localsend/v2/prepare-upload'),
      );
      prepReq.headers.contentType = ContentType.json;
      prepReq.write(jsonEncode({
        'info': {
          'alias': 'LocalSend-CLI',
          'version': protocolVersion,
          'deviceModel': 'CLI',
          'deviceType': 'headless',
          'token': 'cli-token',
          'port': defaultPort,
          'protocol': 'http',
          'hasWebInterface': false,
        },
        'files': fileMeta,
      }));
      final prepResp = await prepReq.close();

      if (prepResp.statusCode == 403) {
        _log('error', 'Transfer declined by receiver');
        exit(1);
      }
      if (prepResp.statusCode != 200) {
        _log('error', 'Prepare failed: HTTP ${prepResp.statusCode}');
        exit(1);
      }

      final body = await utf8.decoder.bind(prepResp).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final remoteSessionId = json['sessionId'] as String? ?? 'session';
      final tokens = (json['files'] as Map<String, dynamic>?) ?? {};

      _log('ok', 'Transfer accepted');

      for (final entry in fileEntries.entries) {
        final token = tokens[entry.key] as String?;
        if (token == null) {
          _log('warn', 'Skipped: ${p.basename(entry.value.path)}');
          continue;
        }

        final file = entry.value;
        final fileName = p.basename(file.path);
        final fileSize = file.lengthSync();

        final uploadUrl = Uri.parse(
          'http://$targetIp:$port/api/localsend/v2/upload'
          '?sessionId=${Uri.encodeComponent(remoteSessionId)}'
          '&fileId=${entry.key}'
          '&token=${Uri.encodeComponent(token)}'
          '&fileName=${Uri.encodeComponent(fileName)}',
        );

        final uploadReq = await client.postUrl(uploadUrl);
        uploadReq.headers
          ..contentType = ContentType.binary
          ..set('Content-Length', '$fileSize');

        var sent = 0;
        await for (final chunk in file.openRead()) {
          uploadReq.add(chunk);
          sent += chunk.length;
          _progress(fileName, sent, fileSize);
        }

        final uploadResp = await uploadReq.close();
        if (uploadResp.statusCode == 200 || uploadResp.statusCode == 204) {
          _log('ok', '$fileName sent', {'file': fileName, 'size': fileSize});
        } else {
          _log('error', '$fileName failed: HTTP ${uploadResp.statusCode}');
        }
      }

      _log('ok', 'Done');
    } catch (e) {
      _log('error', 'Transfer error: $e');
      exit(1);
    } finally {
      client.close();
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }
}
