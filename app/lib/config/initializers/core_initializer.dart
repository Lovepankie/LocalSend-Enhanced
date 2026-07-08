import 'package:common/model/dto/file_dto.dart';
import 'package:common/util/logger.dart';
import 'package:dart_mappable/dart_mappable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:localsend_app/rust/api/logging.dart' as rust_logging;
import 'package:localsend_app/rust/frb_generated.dart';
import 'package:localsend_app/util/rhttp.dart';
import 'package:logging/logging.dart';
import 'package:rhttp/rhttp.dart';

final _logger = Logger('CoreInitializer');

/// Initializes Flutter bindings, logging, Dart mappers, Rust FFI, and HTTP client.
Future<void> initCore(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  initLogger(
    args.contains('-v') || args.contains('--verbose') ? Level.ALL : Level.INFO,
  );
  MapperContainer.globals.use(const FileDtoMapper());

  await RustLib.init();

  if (kDebugMode) {
    try {
      await rust_logging.enableDebugLogging();
    } catch (e) {
      _logger.warning('Enabling debug logging failed', e);
    }
  }

  await Rhttp.init();
}
