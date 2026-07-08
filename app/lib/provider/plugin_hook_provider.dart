import 'package:localsend_app/provider/persistence_provider.dart';
import 'package:localsend_app/service/plugin_hook_service.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

final pluginHookProvider =
    NotifierProvider<PluginHookNotifier, List<ReceiveHook>>((ref) {
      return PluginHookNotifier(ref.read(persistenceProvider));
    });

class PluginHookNotifier extends Notifier<List<ReceiveHook>> {
  PluginHookNotifier(this._persistence);

  final PersistenceService _persistence;

  @override
  List<ReceiveHook> init() => _persistence.getHooks();

  void addHook({
    required String name,
    required HookType type,
    required String target,
  }) {
    final hook = ReceiveHook(
      id: _uuid.v4(),
      name: name,
      type: type,
      target: target,
    );
    state = [...state, hook];
    _persistence.setHooks(state);
  }

  void removeHook(String id) {
    state = state.where((h) => h.id != id).toList();
    _persistence.setHooks(state);
  }

  PluginHookService get service => PluginHookService(hooks: state);
}
