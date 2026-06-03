import 'package:flutter/material.dart';
import 'package:localsend_app/provider/network/webrtc/signaling_provider.dart';
import 'package:localsend_app/provider/persistence_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';

const _defaultSignalingServer = 'wss://public.localsend.org/v1/ws';
const _defaultStunServer = 'stun:stun.localsend.org:5349';

class SignalingServerPage extends StatefulWidget {
  const SignalingServerPage({super.key});

  @override
  State<SignalingServerPage> createState() => _SignalingServerPageState();
}

class _SignalingServerPageState extends State<SignalingServerPage> {
  late List<TextEditingController> _signalingControllers;
  late List<TextEditingController> _stunControllers;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final ref = context.ref;
    final state = ref.read(signalingProvider);
    _signalingControllers = state.signalingServers
        .map((s) => TextEditingController(text: s))
        .toList();
    _stunControllers = state.stunServers
        .map((s) => TextEditingController(text: s))
        .toList();
    if (_signalingControllers.isEmpty) {
      _signalingControllers.add(TextEditingController(text: _defaultSignalingServer));
    }
    if (_stunControllers.isEmpty) {
      _stunControllers.add(TextEditingController(text: _defaultStunServer));
    }
  }

  @override
  void dispose() {
    for (final c in _signalingControllers) {
      c.dispose();
    }
    for (final c in _stunControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ref = context.ref;
    final persistence = ref.read(persistenceProvider);

    final signalingServers = _signalingControllers
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final stunServers = _stunControllers
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    await persistence.setSignalingServers(signalingServers);
    await persistence.setStunServers(stunServers);

    // Reconnect with new servers
    if (mounted) {
      ref.redux(signalingProvider).dispatch(SetupSignalingConnection());
      Navigator.of(context).pop();
    }
  }

  void _resetToDefaults() {
    setState(() {
      _signalingControllers = [TextEditingController(text: _defaultSignalingServer)];
      _stunControllers = [TextEditingController(text: _defaultStunServer)];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Signaling Servers'),
        actions: [
          TextButton(
            onPressed: _resetToDefaults,
            child: const Text('Reset'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(
            title: 'Signaling Servers (WSS)',
            hint: 'Used for cross-network device discovery via WebRTC.',
          ),
          ..._signalingControllers.asMap().entries.map((e) => _ServerField(
                controller: e.value,
                label: 'Server ${e.key + 1}',
                onRemove: _signalingControllers.length > 1
                    ? () => setState(() => _signalingControllers.removeAt(e.key))
                    : null,
              )),
          TextButton.icon(
            onPressed: () => setState(
              () => _signalingControllers.add(TextEditingController()),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Add Server'),
          ),
          const SizedBox(height: 24),
          _SectionHeader(
            title: 'STUN Servers',
            hint: 'Used for NAT traversal in WebRTC connections.',
          ),
          ..._stunControllers.asMap().entries.map((e) => _ServerField(
                controller: e.value,
                label: 'STUN ${e.key + 1}',
                onRemove: _stunControllers.length > 1
                    ? () => setState(() => _stunControllers.removeAt(e.key))
                    : null,
              )),
          TextButton.icon(
            onPressed: () => setState(
              () => _stunControllers.add(TextEditingController()),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Add STUN Server'),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save & Reconnect'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String hint;

  const _SectionHeader({required this.title, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 2),
          Text(hint, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ServerField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final VoidCallback? onRemove;

  const _ServerField({
    required this.controller,
    required this.label,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: label,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: TextInputType.url,
            ),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: onRemove,
              color: Theme.of(context).colorScheme.error,
            ),
          ],
        ],
      ),
    );
  }
}
