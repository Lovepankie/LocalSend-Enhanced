import 'package:flutter/material.dart';
import 'package:localsend_app/provider/network/transfer_queue_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// Bottom sheet that shows the current transfer queue status.
class TransferQueueSheet extends StatelessWidget {
  const TransferQueueSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const TransferQueueSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final queue = context.watch(transferQueueProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      minChildSize: 0.2,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, controller) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Transfer Queue',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${queue.items.length}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (queue.items.any((i) =>
                      i.status == QueuedTransferStatus.done ||
                      i.status == QueuedTransferStatus.failed))
                    TextButton(
                      onPressed: () =>
                          context.notifier(transferQueueProvider).clearFinished(),
                      child: const Text('Clear done'),
                    ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: queue.items.isEmpty
                  ? const Center(child: Text('No transfers queued'))
                  : ListView.builder(
                      controller: controller,
                      itemCount: queue.items.length,
                      itemBuilder: (_, i) => _QueueItem(item: queue.items[i]),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _QueueItem extends StatelessWidget {
  final QueuedTransfer item;

  const _QueueItem({required this.item});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (item.status) {
      QueuedTransferStatus.waiting => (Icons.schedule, Colors.grey),
      QueuedTransferStatus.sending => (Icons.upload, Theme.of(context).colorScheme.primary),
      QueuedTransferStatus.done => (Icons.check_circle, Colors.green),
      QueuedTransferStatus.failed => (Icons.error_outline, Theme.of(context).colorScheme.error),
    };

    return ListTile(
      leading: item.status == QueuedTransferStatus.sending
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, color: color),
      title: Text(item.target.alias, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        item.status == QueuedTransferStatus.failed
            ? item.errorMessage ?? 'Failed'
            : '${item.files.length} file${item.files.length == 1 ? '' : 's'}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: item.status != QueuedTransferStatus.sending
          ? IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () =>
                  context.notifier(transferQueueProvider).dismiss(item.id),
            )
          : null,
    );
  }
}
