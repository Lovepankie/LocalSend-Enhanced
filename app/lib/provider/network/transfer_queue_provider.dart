import 'package:common/model/device.dart';
import 'package:localsend_app/model/cross_file.dart';
import 'package:localsend_app/provider/network/send_provider.dart';
import 'package:logging/logging.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();
final _logger = Logger('TransferQueue');

enum QueuedTransferStatus { waiting, sending, done, failed }

class QueuedTransfer {
  final String id;
  final Device target;
  final List<CrossFile> files;
  final QueuedTransferStatus status;
  final String? errorMessage;

  const QueuedTransfer({
    required this.id,
    required this.target,
    required this.files,
    required this.status,
    this.errorMessage,
  });

  QueuedTransfer copyWith({
    QueuedTransferStatus? status,
    String? errorMessage,
  }) {
    return QueuedTransfer(
      id: id,
      target: target,
      files: files,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class TransferQueueState {
  final List<QueuedTransfer> items;
  final bool running;

  const TransferQueueState({required this.items, required this.running});

  TransferQueueState copyWith({List<QueuedTransfer>? items, bool? running}) {
    return TransferQueueState(
      items: items ?? this.items,
      running: running ?? this.running,
    );
  }

  List<QueuedTransfer> get pending =>
      items.where((i) => i.status == QueuedTransferStatus.waiting).toList();
}

final transferQueueProvider =
    NotifierProvider<TransferQueueNotifier, TransferQueueState>((ref) {
      return TransferQueueNotifier();
    });

class TransferQueueNotifier extends Notifier<TransferQueueState> {
  @override
  TransferQueueState init() =>
      const TransferQueueState(items: [], running: false);

  /// Adds a transfer to the queue and starts processing if idle.
  Future<void> enqueue({
    required Device target,
    required List<CrossFile> files,
  }) async {
    final entry = QueuedTransfer(
      id: _uuid.v4(),
      target: target,
      files: files,
      status: QueuedTransferStatus.waiting,
    );

    state = state.copyWith(items: [...state.items, entry]);
    _logger.info('Queued transfer to ${target.alias}: ${files.length} file(s)');

    if (!state.running) {
      await _processQueue();
    }
  }

  /// Removes a completed or failed item from the queue.
  void dismiss(String id) {
    state = state.copyWith(
      items: state.items.where((i) => i.id != id).toList(),
    );
  }

  /// Clears all non-running items (waiting + done + failed).
  void clearFinished() {
    state = state.copyWith(
      items: state.items
          .where((i) => i.status == QueuedTransferStatus.sending)
          .toList(),
    );
  }

  Future<void> _processQueue() async {
    state = state.copyWith(running: true);

    while (true) {
      final pending = state.pending;
      if (pending.isEmpty) break;

      final entry = pending.first;
      _updateItem(entry.id, QueuedTransferStatus.sending);

      try {
        await ref
            .notifier(sendProvider)
            .startSession(
              target: entry.target,
              files: entry.files,
              background: true,
            );
        _updateItem(entry.id, QueuedTransferStatus.done);
        _logger.info('Queue: finished sending to ${entry.target.alias}');
      } catch (e) {
        _updateItem(
          entry.id,
          QueuedTransferStatus.failed,
          errorMessage: e.toString(),
        );
        _logger.warning('Queue: failed sending to ${entry.target.alias}', e);
      }
    }

    state = state.copyWith(running: false);
  }

  void _updateItem(
    String id,
    QueuedTransferStatus status, {
    String? errorMessage,
  }) {
    state = state.copyWith(
      items: state.items.map((i) {
        if (i.id == id)
          return i.copyWith(status: status, errorMessage: errorMessage);
        return i;
      }).toList(),
    );
  }
}
