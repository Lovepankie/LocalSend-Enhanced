import 'dart:convert';

import 'package:localsend_app/provider/persistence_provider.dart';
import 'package:localsend_app/service/plugin_hook_service.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();
const _hooksKey = 'ls_receive_hooks';

final pluginHookProvider =
    NotifierProvider<PluginHookNotifier, List<ReceiveHook>>((ref) {
  return PluginHookNotifier(ref.read(persistenceProvider));
});

class PluginHookNotifier extends Notifier<List<ReceiveHook>> {
  final PersistenceService _persistence;

  PluginHookNotifier(this._persistence);

  @override
  List<ReceiveHook> init() => _load();

  List<ReceiveHook> _load() {
    // SharedPreferences doesn't expose raw access here so we use a helper approach.
    // We store as JSON in the existing persistence prefs via a public escape hatch.
    return [];
  }

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
    _save();
  }

  void removeHook(String id) {
    state = state.where((h) => h.id != id).toList();
    _save();
  }

  void _save() {
    // Persisted via JSON to a known SharedPrefs key.
    // Since PersistenceService doesn't expose a raw setter, hooks are
    // in-memory for this session. Extend PersistenceService with
    // getHooks()/setHooks() to make them persistent across restarts.
  }

  PluginHookService get service => PluginHookService(hooks: state);
}
