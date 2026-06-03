import 'package:localsend_app/service/e2e_encryption_service.dart';
import 'package:refena_flutter/refena_flutter.dart';

class E2ESessionState {
  final bool enabled;
  final String? passphrase;
  final E2EEncryptionService? service;

  const E2ESessionState({
    required this.enabled,
    this.passphrase,
    this.service,
  });

  static const disabled = E2ESessionState(enabled: false);
}

final e2eSessionProvider =
    NotifierProvider<E2ESessionNotifier, E2ESessionState>((ref) {
  return E2ESessionNotifier();
});

class E2ESessionNotifier extends Notifier<E2ESessionState> {
  @override
  E2ESessionState init() => E2ESessionState.disabled;

  /// Enables E2E encryption for this session with [passphrase].
  void enable(String passphrase) {
    state = E2ESessionState(
      enabled: true,
      passphrase: passphrase,
      service: E2EEncryptionService(passphrase),
    );
  }

  /// Disables E2E encryption. The passphrase is not persisted.
  void disable() {
    state = E2ESessionState.disabled;
  }
}
