import 'package:flutter/material.dart';
import 'package:localsend_app/provider/e2e_session_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';

class E2ESettingsPage extends StatefulWidget {
  const E2ESettingsPage({super.key});

  @override
  State<E2ESettingsPage> createState() => _E2ESettingsPageState();
}

class _E2ESettingsPageState extends State<E2ESettingsPage> {
  final _controller = TextEditingController();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    final state = context.ref.read(e2eSessionProvider);
    if (state.passphrase != null) {
      _controller.text = state.passphrase!;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch(e2eSessionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('End-to-End Encryption')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lock_outline, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Session E2E Encryption',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'When enabled, all files sent in this session are encrypted '
                    'with the shared passphrase before transfer. '
                    'Both devices must use the same passphrase. '
                    'The passphrase is never transmitted — only you and the recipient know it.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          SwitchListTile(
            title: const Text('Enable E2E Encryption'),
            subtitle: Text(state.enabled ? 'Enabled for this session' : 'Disabled'),
            value: state.enabled,
            onChanged: (v) {
              if (!v) {
                context.notifier(e2eSessionProvider).disable();
              } else if (_controller.text.trim().isNotEmpty) {
                context.notifier(e2eSessionProvider).enable(_controller.text.trim());
              }
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            obscureText: _obscure,
            enabled: !state.enabled,
            decoration: InputDecoration(
              labelText: 'Shared Passphrase',
              border: const OutlineInputBorder(),
              helperText: state.enabled
                  ? 'Disable encryption to change the passphrase'
                  : 'Enter a passphrase agreed with the recipient',
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),
          if (!state.enabled)
            FilledButton.icon(
              onPressed: _controller.text.trim().isEmpty
                  ? null
                  : () {
                      context
                          .notifier(e2eSessionProvider)
                          .enable(_controller.text.trim());
                    },
              icon: const Icon(Icons.lock),
              label: const Text('Enable with This Passphrase'),
            ),
          if (state.enabled) ...[
            FilledButton.icon(
              onPressed: () => context.notifier(e2eSessionProvider).disable(),
              icon: const Icon(Icons.lock_open),
              label: const Text('Disable Encryption'),
            ),
            const SizedBox(height: 8),
            Center(
              child: Chip(
                avatar: const Icon(Icons.check_circle, color: Colors.green, size: 18),
                label: const Text('Encryption active'),
                backgroundColor: Colors.green.withOpacity(0.1),
              ),
            ),
          ],
          const SizedBox(height: 32),
          const _SecurityNote(),
        ],
      ),
    );
  }
}

class _SecurityNote extends StatelessWidget {
  const _SecurityNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Security Notes', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 6),
          Text('• Key derivation: PBKDF2-HMAC-SHA256 (100,000 iterations)'),
          Text('• Encryption: XOR with HMAC-SHA256 keystream'),
          Text('• Integrity: HMAC-SHA256 tag on every file'),
          Text('• The passphrase is session-only and never saved to disk'),
          Text('• Files are still sent over HTTPS — E2E adds an extra layer'),
        ],
      ),
    );
  }
}
