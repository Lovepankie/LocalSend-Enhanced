import 'package:flutter/material.dart';
import 'package:localsend_app/provider/logging/audit_log_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';

class AuditLogPage extends StatelessWidget {
  const AuditLogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = context.watch(auditLogProvider).reversed.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer Audit Log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear log',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Clear Audit Log?'),
                  content: const Text(
                    'All transfer records will be deleted. This cannot be undone.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                await context.notifier(auditLogProvider).clearAll();
              }
            },
          ),
        ],
      ),
      body: entries.isEmpty
          ? const Center(child: Text('No transfers recorded yet.'))
          : ListView.separated(
              itemCount: entries.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) => _AuditTile(entry: entries[i]),
            ),
    );
  }
}

class _AuditTile extends StatelessWidget {
  final AuditEntry entry;

  const _AuditTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isSent = entry.direction == AuditDirection.sent;
    final color = entry.success
        ? Colors.green
        : Theme.of(context).colorScheme.error;

    return ListTile(
      leading: Icon(isSent ? Icons.upload : Icons.download, color: color),
      title: Text(entry.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${isSent ? "To" : "From"} ${entry.peerAlias} · '
        '${_formatSize(entry.fileSize)} · '
        '${_formatTime(entry.timestamp)}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: entry.success
          ? const Icon(Icons.check, color: Colors.green, size: 18)
          : Tooltip(
              message: entry.errorMessage ?? 'Failed',
              child: Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.error,
                size: 18,
              ),
            ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}
