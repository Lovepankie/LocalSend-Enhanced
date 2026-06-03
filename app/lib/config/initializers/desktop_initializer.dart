import 'dart:io';

import 'package:common/api_route_builder.dart';
import 'package:common/constants.dart';
import 'package:flutter/foundation.dart';
import 'package:localsend_app/provider/persistence_provider.dart';
import 'package:localsend_app/util/native/autostart_helper.dart';
import 'package:localsend_app/util/native/macos_channel.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/util/native/tray_helper.dart';
import 'package:localsend_app/util/rhttp.dart';
import 'package:logging/logging.dart';
import 'package:rhttp/rhttp.dart';
import 'package:window_manager/window_manager.dart';
import 'package:localsend_app/provider/window_dimensions_provider.dart';

final _logger = Logger('DesktopInitializer');

const startHiddenFlag = '--hidden';

class DesktopInitResult {
  final bool startHidden;

  const DesktopInitResult({required this.startHidden});
}

/// Handles all desktop-specific initialization:
/// single-instance enforcement, tray, window dimensions, and start-hidden logic.
/// Returns null on non-desktop platforms.
Future<DesktopInitResult?> initDesktop(
  List<String> args,
  PersistenceService persistence,
) async {
  if (!checkPlatformIsDesktop()) return null;

  // If another instance is already running, signal it to show and exit this one.
  final client = createRhttpClient(
    const Duration(milliseconds: 100),
    persistence.getSecurityContext(),
  );
  try {
    await client.post(
      ApiRoute.show.targetRaw(
        '127.0.0.1',
        persistence.getPort(),
        persistence.isHttps(),
        peerProtocolVersion,
      ),
      query: {'token': persistence.getShowToken()},
      body: HttpBody.json({'args': args}),
    );
    exit(0);
  } catch (_) {}

  try {
    await initTray();
  } catch (e) {
    _logger.warning('Initializing tray failed: $e');
  }

  await WindowManager.instance.ensureInitialized();
  await WindowDimensionsController(persistence).initDimensionsConfiguration();

  bool startHidden = false;
  if (args.contains(startHiddenFlag)) {
    startHidden = true;
  } else if (defaultTargetPlatform == TargetPlatform.macOS) {
    startHidden = await isLaunchedAsLoginItem() && await getLaunchAtLoginMinimized();
  }

  if (defaultTargetPlatform == TargetPlatform.macOS) {
    await setupStatusBar();
  }

  return DesktopInitResult(startHidden: startHidden);
}
