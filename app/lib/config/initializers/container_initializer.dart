import 'package:common/isolate.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:localsend_app/config/initializers/desktop_initializer.dart';
import 'package:localsend_app/config/refena.dart';
import 'package:localsend_app/provider/animation_provider.dart';
import 'package:localsend_app/provider/app_arguments_provider.dart';
import 'package:localsend_app/provider/device_info_provider.dart';
import 'package:localsend_app/provider/persistence_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/provider/tv_provider.dart';
import 'package:localsend_app/provider/window_dimensions_provider.dart';
import 'package:localsend_app/util/native/content_uri_helper.dart';
import 'package:localsend_app/util/native/device_info_helper.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/util/rhttp.dart';
import 'package:localsend_app/util/ui/dynamic_colors.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:rhttp/rhttp.dart';

// [FOSS_REMOVE_START]
import 'package:localsend_app/provider/purchase_provider.dart';
// [FOSS_REMOVE_END]

/// Builds the RefenaContainer with all provider overrides and initializes isolates.
Future<RefenaContainer> initContainer({
  required List<String> args,
  required PersistenceService persistence,
  required dynamic dynamicColors,
  required DesktopInitResult? desktop,
}) async {
  final startHidden = desktop?.startHidden ?? false;

  final container = RefenaContainer(
    observers: kDebugMode ? [CustomRefenaObserver()] : [],
    overrides: [
      persistenceProvider.overrideWithValue(persistence),
      deviceRawInfoProvider.overrideWithValue(await getDeviceInfo()),
      appArgumentsProvider.overrideWithValue(args),
      tvProvider.overrideWithValue(await checkIfTv()),
      dynamicColorsProvider.overrideWithValue(dynamicColors),
      sleepProvider.overrideWithInitialState((ref) => startHidden),
    ],
    platformHint: RefenaScope.getPlatformHint(),
  );

  container.set(
    parentIsolateProvider.overrideWithNotifier((ref) {
      final settings = ref.read(settingsProvider);
      return IsolateController(
        initialState: ParentIsolateState.initial(
          SyncState(
            init: () async {
              await Rhttp.init();
            },
            rootIsolateToken: RootIsolateToken.instance!,
            httpClientFactory: RhttpWrapper.create,
            securityContext: persistence.getSecurityContext(),
            deviceInfo: ref.read(deviceInfoProvider),
            alias: settings.alias,
            port: settings.port,
            networkWhitelist: settings.networkWhitelist,
            networkBlacklist: settings.networkBlacklist,
            protocol: settings.https ? ProtocolType.https : ProtocolType.http,
            multicastGroup: settings.multicastGroup,
            discoveryTimeout: settings.discoveryTimeout,
            serverRunning: true,
            download: false,
          ),
        ),
      );
    }),
  );

  await container
      .redux(parentIsolateProvider)
      .dispatchAsync(
        IsolateSetupAction(
          uriContentStreamResolver: AndroidUriContentStreamResolver(),
          uploadIsolateCount: persistence.getParallelUploads(),
        ),
      );

  return container;
}
