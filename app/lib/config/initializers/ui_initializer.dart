import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/util/i18n.dart';

/// Initializes i18n translations and route transition defaults.
Future<void> initUi() async {
  await initI18n();
  setDefaultRouteTransition();
}
