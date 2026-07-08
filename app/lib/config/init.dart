import 'dart:async';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/config/initializers/container_initializer.dart';
import 'package:localsend_app/config/initializers/core_initializer.dart';
import 'package:localsend_app/config/initializers/desktop_initializer.dart';
import 'package:localsend_app/config/initializers/persistence_initializer.dart';
import 'package:localsend_app/config/initializers/ui_initializer.dart';
import 'package:localsend_app/pages/home_page.dart';
import 'package:localsend_app/pages/home_page_controller.dart';
import 'package:localsend_app/provider/app_arguments_provider.dart';
import 'package:localsend_app/provider/network/nearby_devices_provider.dart';
import 'package:localsend_app/provider/network/network_error_provider.dart';
import 'package:localsend_app/provider/network/server/server_provider.dart';
import 'package:localsend_app/provider/network/webrtc/signaling_provider.dart';
import 'package:localsend_app/provider/selection/selected_sending_files_provider.dart';
import 'package:localsend_app/util/native/cross_file_converters.dart';
import 'package:localsend_app/util/native/macos_channel.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/util/ui/snackbar.dart';
import 'package:logging/logging.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:share_handler/share_handler.dart';

// [FOSS_REMOVE_START]
import 'package:localsend_app/provider/purchase_provider.dart';
// [FOSS_REMOVE_END]

import 'package:flutter_displaymode/flutter_displaymode.dart';

final _logger = Logger('Init');

/// Orchestrates all pre-MaterialApp initialization steps.
Future<RefenaContainer> preInit(List<String> args) async {
  await initCore(args);

  final (:persistence, :dynamicColors) = await initPersistence();

  await initUi();

  final desktop = await initDesktop(args, persistence);

  if (desktop != null) {
    doWhenWindowReady(() {
      if (desktop.startHidden) {
        unawaited(hideToTray());
      } else {
        unawaited(showFromTray());
      }
    });
  }

  return initContainer(
    args: args,
    persistence: persistence,
    dynamicColors: dynamicColors,
    desktop: desktop,
  );
}

StreamSubscription? _sharedMediaSubscription;

/// Called after home page initialization.
Future<void> postInit(BuildContext context, Ref ref, bool appStart) async {
  await updateSystemOverlayStyle(context);

  if (checkPlatform([TargetPlatform.android])) {
    try {
      await FlutterDisplayMode.setHighRefreshRate();
    } catch (e) {
      _logger.warning('Setting high refresh rate failed', e);
    }
  }

  try {
    await ref.notifier(serverProvider).startServerFromSettings();
  } catch (e) {
    if (context.mounted) {
      context.showSnackBar(e.toString());
    }
  }

  try {
    ref
        .redux(nearbyDevicesProvider)
        .dispatchAsync(StartMulticastListener()); // ignore: unawaited_futures
  } catch (e) {
    _logger.warning('Starting multicast listener failed', e);
    ref
        .notifier(networkErrorProvider)
        .addWarning('Multicast discovery unavailable: $e');
  }

  ref.redux(signalingProvider).dispatch(SetupSignalingConnection());

  if (appStart) {
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      pendingFilesStream.listen((files) async {
        await ref.global.dispatchAsync(
          _HandleAppStartArgumentsAction(args: files),
        );
      });

      pendingStringsStream.listen((pendingStrings) {
        for (final string in pendingStrings) {
          ref
              .redux(selectedSendingFilesProvider)
              .dispatch(AddMessageAction(message: string));
        }
        ref
            .redux(homePageControllerProvider)
            .dispatch(ChangeTabAction(HomeTab.send));
      });

      await setupMethodCallHandler();
    } else {
      final args = ref.read(appArgumentsProvider);
      await ref.global.dispatchAsync(
        _HandleAppStartArgumentsAction(args: args),
      );
    }
  }

  bool hasInitialShare = false;

  if (checkPlatformCanReceiveShareIntent()) {
    final shareHandler = ShareHandlerPlatform.instance;

    if (appStart) {
      final initialSharedPayload = await shareHandler.getInitialSharedMedia();
      if (initialSharedPayload != null) {
        hasInitialShare = true;
        // ignore: unawaited_futures
        ref.global.dispatchAsync(
          _HandleShareIntentAction(payload: initialSharedPayload),
        );
      }
    }

    _sharedMediaSubscription?.cancel(); // ignore: unawaited_futures
    _sharedMediaSubscription = shareHandler.sharedMediaStream.listen((
      SharedMedia payload,
    ) async {
      await ref.global.dispatchAsync(
        _HandleShareIntentAction(payload: payload),
      );
    });
  }

  if (appStart &&
      !hasInitialShare &&
      (checkPlatformWithGallery() || checkPlatformCanReceiveShareIntent())) {
    ref.global.dispatchAsync(ClearCacheAction()); // ignore: unawaited_futures
  }

  // [FOSS_REMOVE_START]
  if (checkPlatformSupportPayment()) {
    // ignore: unawaited_futures
    ref.redux(purchaseProvider).dispatchAsync(InitPurchaseStream());
  }
  // [FOSS_REMOVE_END]
}

class _HandleShareIntentAction extends AsyncGlobalAction {
  final SharedMedia payload;

  _HandleShareIntentAction({required this.payload});

  @override
  Future<void> reduce() async {
    final message = payload.content;
    if (message != null && message.trim().isNotEmpty) {
      ref
          .redux(selectedSendingFilesProvider)
          .dispatch(AddMessageAction(message: message));
    }
    await ref
        .redux(selectedSendingFilesProvider)
        .dispatchAsync(
          AddFilesAction(
            files:
                payload.attachments
                    ?.where((a) => a != null)
                    .cast<SharedAttachment>() ??
                <SharedAttachment>[],
            converter: CrossFileConverters.convertSharedAttachment,
          ),
        );
    ref
        .redux(homePageControllerProvider)
        .dispatch(ChangeTabAction(HomeTab.send));
  }
}

class _HandleAppStartArgumentsAction extends AsyncGlobalAction {
  final List<String> args;

  _HandleAppStartArgumentsAction({required this.args});

  @override
  Future<void> reduce() async {
    final filesAdded = await ref
        .redux(selectedSendingFilesProvider)
        .dispatchAsyncTakeResult(LoadSelectionFromArgsAction(args));
    if (filesAdded) {
      ref
          .redux(homePageControllerProvider)
          .dispatch(ChangeTabAction(HomeTab.send));
    }
  }
}
