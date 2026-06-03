import 'package:refena_flutter/refena_flutter.dart';

/// Severity of a surfaced network error.
enum NetworkErrorSeverity { warning, error }

class NetworkError {
  final String message;
  final NetworkErrorSeverity severity;
  final DateTime timestamp;

  const NetworkError({
    required this.message,
    required this.severity,
    required this.timestamp,
  });
}

class NetworkErrorState {
  final List<NetworkError> errors;

  const NetworkErrorState({required this.errors});

  NetworkErrorState withError(NetworkError e) =>
      NetworkErrorState(errors: [...errors, e]);

  NetworkErrorState withoutFirst() =>
      NetworkErrorState(errors: errors.skip(1).toList());

  NetworkErrorState cleared() => const NetworkErrorState(errors: []);
}

final networkErrorProvider = NotifierProvider<NetworkErrorNotifier, NetworkErrorState>((ref) {
  return NetworkErrorNotifier();
});

class NetworkErrorNotifier extends Notifier<NetworkErrorState> {
  @override
  NetworkErrorState init() => const NetworkErrorState(errors: []);

  void addWarning(String message) {
    state = state.withError(NetworkError(
      message: message,
      severity: NetworkErrorSeverity.warning,
      timestamp: DateTime.now(),
    ));
  }

  void addError(String message) {
    state = state.withError(NetworkError(
      message: message,
      severity: NetworkErrorSeverity.error,
      timestamp: DateTime.now(),
    ));
  }

  void dismissFirst() {
    state = state.withoutFirst();
  }

  void clearAll() {
    state = state.cleared();
  }
}
