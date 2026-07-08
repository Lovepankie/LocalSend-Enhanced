import 'package:localsend_app/provider/persistence_provider.dart';
import 'package:localsend_app/util/native/context_menu_helper.dart';
import 'package:localsend_app/util/ui/dynamic_colors.dart';

/// Initializes PersistenceService and handles first-launch side effects.
Future<({PersistenceService persistence, dynamic dynamicColors})>
initPersistence() async {
  final dynamicColors = await getDynamicColors();

  final persistence = await PersistenceService.initialize(
    supportsDynamicColors: dynamicColors != null,
  );

  if (persistence.isFirstAppStart && !persistence.isPortableMode()) {
    await enableContextMenu();
  }

  return (persistence: persistence, dynamicColors: dynamicColors);
}
