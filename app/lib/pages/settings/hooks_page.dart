import 'package:flutter/material.dart';
import 'package:localsend_app/provider/plugin_hook_provider.dart';
import 'package:localsend_app/service/plugin_hook_service.dart';
import 'package:refena_flutter/refena_flutter.dart';

class HooksPage extends StatelessWidget {
  const HooksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final hooks = context.watch(pluginHookProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receive Hooks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDialog(context),
          ),
        ],
      ),
      body: hooks.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.webhook, size: 60, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No hooks configured'),
                  const SizedBox(height: 8),
                  Text(
                    'Hooks run a shell command or call a URL\nwhen a file is received.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _showAddDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Hook'),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: hooks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _HookCard(hook: hooks[i]),
            ),
    );
  }

  Future<void> _showAddDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (_) => const _AddHookDialog(),
    );
  }
}

class _HookCard extends StatelessWidget {
  final ReceiveHook hook;

  const _HookCard({required this.hook});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(
          hook.type == HookType.webhook ? Icons.language : Icons.terminal,
        ),
        title: Text(hook.name),
        subtitle: Text(
          hook.target,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          color: Theme.of(context).colorScheme.error,
          onPressed: () => context.notifier(pluginHookProvider).removeHook(hook.id),
        ),
      ),
    );
  }
}

class _AddHookDialog extends StatefulWidget {
  const _AddHookDialog();

  @override
  State<_AddHookDialog> createState() => _AddHookDialogState();
}

class _AddHookDialogState extends State<_AddHookDialog> {
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  HookType _type = HookType.shellCommand;

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Receive Hook'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Hook Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<HookType>(
              selected: {_type},
              onSelectionChanged: (v) => setState(() => _type = v.first),
              segments: const [
                ButtonSegment(
                  value: HookType.shellCommand,
                  label: Text('Shell'),
                  icon: Icon(Icons.terminal, size: 16),
                ),
                ButtonSegment(
                  value: HookType.webhook,
                  label: Text('Webhook'),
                  icon: Icon(Icons.language, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _targetController,
              decoration: InputDecoration(
                labelText: _type == HookType.shellCommand ? 'Shell Command' : 'URL',
                hintText: _type == HookType.shellCommand
                    ? 'e.g. notify-send "File received: \$LS_FILE_NAME"'
                    : 'https://your-server.com/webhook',
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
              minLines: 1,
            ),
            const SizedBox(height: 8),
            if (_type == HookType.shellCommand)
              Text(
                'Available env vars: \$LS_FILE_NAME, \$LS_FILE_PATH, '
                '\$LS_FILE_SIZE, \$LS_SENDER, \$LS_TIMESTAMP',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _nameController.text.trim().isEmpty || _targetController.text.trim().isEmpty
              ? null
              : () {
                  context.notifier(pluginHookProvider).addHook(
                        name: _nameController.text.trim(),
                        type: _type,
                        target: _targetController.text.trim(),
                      );
                  Navigator.pop(context);
                },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
