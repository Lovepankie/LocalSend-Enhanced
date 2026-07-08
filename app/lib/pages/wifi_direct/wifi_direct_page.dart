import 'package:flutter/material.dart';
import 'package:localsend_app/provider/direct/direct_pairing.dart';
import 'package:localsend_app/provider/network/wifi_direct_provider.dart';
import 'package:localsend_app/service/wifi_direct_service.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// WiFi Direct pairing page.
///
/// Host mode (canHost == true):
///   Shows a QR code encoding the hotspot SSID + passphrase.
///   The joiner scans it → device connects automatically → LocalSend discovery runs.
///
/// iOS host (canHost == false):
///   Shows instructions to enable Personal Hotspot manually + displays QR
///   once user enters their hotspot name and password.
///
/// Join mode:
///   Opens the device camera to scan the host's QR code and joins the hotspot.
class WifiDirectPage extends StatelessWidget {
  const WifiDirectPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch(wifiDirectProvider);
    final notifier = context.notifier(wifiDirectProvider);
    final canHost = notifier.canHost;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Direct Connect'),
        actions: [
          if (state.mode != WifiDirectMode.idle)
            TextButton(
              onPressed: () async {
                if (state.mode == WifiDirectMode.hosting) {
                  await notifier.stopHotspot();
                } else {
                  await notifier.leaveHotspot();
                }
              },
              child: const Text('Disconnect'),
            ),
        ],
      ),
      body: _Body(state: state, canHost: canHost),
    );
  }
}

class _Body extends StatelessWidget {
  final WifiDirectState state;
  final bool canHost;

  const _Body({required this.state, required this.canHost});

  @override
  Widget build(BuildContext context) {
    return switch (state.mode) {
      WifiDirectMode.idle => _IdleView(canHost: canHost),
      WifiDirectMode.hosting => _HostingView(
          pairing: state.pairing,
          credentials: state.credentials,
        ),
      WifiDirectMode.joining => const _JoiningView(),
      WifiDirectMode.connected => const _ConnectedView(),
    };
  }
}

/// Initial selection: Host or Join.
class _IdleView extends StatelessWidget {
  final bool canHost;

  const _IdleView({required this.canHost});

  @override
  Widget build(BuildContext context) {
    final notifier = context.notifier(wifiDirectProvider);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_tethering, size: 80),
            const SizedBox(height: 24),
            Text(
              'Connect directly without a router',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'One device creates a hotspot, the other scans a QR code to join. '
              'No internet required.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            if (canHost) ...[
              FilledButton.icon(
                onPressed: () => notifier.startHotspot(),
                icon: const Icon(Icons.wifi_tethering),
                label: const Text('Host — Create Hotspot'),
              ),
              const SizedBox(height: 12),
            ] else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(Icons.info_outline, size: 28),
                      const SizedBox(height: 8),
                      const Text(
                        'On iOS, enable Personal Hotspot in Settings, '
                        'then tap "Join" on the other device and scan your hotspot QR.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            OutlinedButton.icon(
              onPressed: () => _openQrScanner(context),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Join — Scan QR Code'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openQrScanner(BuildContext context) async {
    // Navigate to QR scanner sub-page.
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const _QrScannerPage()));
  }
}

/// Shows the QR code for the hosted hotspot.
class _HostingView extends StatelessWidget {
  final PairingPayload? pairing;
  final HotspotCredentials? credentials;

  const _HostingView({this.pairing, this.credentials});

  @override
  Widget build(BuildContext context) {
    if (credentials == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Primary payload is the lsd:// pairing URI (carries host IP + port so the
    // guest connects directly); fall back to the plain WiFi QR if the host IP
    // could not be resolved.
    final payload = pairing?.toUri() ?? credentials!.toQrPayload();
    final webUrl = pairing?.baseUrl;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Scan to connect',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Point the other device\'s camera at this QR code.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: SizedBox(
                width: 220,
                height: 220,
                child: PrettyQrView.data(data: payload),
              ),
            ),
            const SizedBox(height: 20),
            _CredentialRow(label: 'Network', value: credentials!.ssid),
            _CredentialRow(label: 'Password', value: credentials!.passphrase),
            if (webUrl != null) ...[
              const SizedBox(height: 8),
              _CredentialRow(label: 'Browser', value: webUrl),
              Text(
                'On a computer: join this network, then open the address above '
                'in any browser — no app needed.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Once connected, LocalSend will discover devices automatically.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _CredentialRow extends StatelessWidget {
  final String label;
  final String value;

  const _CredentialRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }
}

class _JoiningView extends StatelessWidget {
  const _JoiningView();

  @override
  Widget build(BuildContext context) {
    final state = context.watch(wifiDirectProvider);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text('Connecting to ${state.credentials?.ssid ?? "hotspot"}…'),
          if (state.errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              state.errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _ConnectedView extends StatelessWidget {
  const _ConnectedView();

  @override
  Widget build(BuildContext context) {
    final state = context.watch(wifiDirectProvider);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 80),
            const SizedBox(height: 16),
            Text('Connected!', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'You are connected to ${state.credentials?.ssid ?? "the hotspot"}. '
              'LocalSend is now discovering nearby devices on this network.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Send'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple QR scanner page using the device camera.
class _QrScannerPage extends StatefulWidget {
  const _QrScannerPage();

  @override
  State<_QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<_QrScannerPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _processing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleRaw(String raw) async {
    if (_processing) return;
    final pairing = PairingPayload.tryParse(raw);
    if (pairing == null) return; // not one of our QR codes
    setState(() => _processing = true);
    await _controller.stop();
    if (!mounted) return;
    await context.notifier(wifiDirectProvider).joinFromPairing(pairing);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR Code')),
      body: Column(
        children: [
          SizedBox(
            height: 300,
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: (capture) {
                    for (final barcode in capture.barcodes) {
                      final raw = barcode.rawValue;
                      if (raw != null) {
                        _handleRaw(raw);
                        break;
                      }
                    }
                  },
                ),
                if (_processing) const CircularProgressIndicator(),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Point the camera at the host device\'s QR code, '
                    'or enter the network details manually below.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  _ManualEntryForm(
                    onCredentials: _onCredentials,
                    processing: _processing,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onCredentials(HotspotCredentials credentials) async {
    setState(() => _processing = true);
    await context.notifier(wifiDirectProvider).joinHotspot(credentials);
    if (mounted) Navigator.of(context).pop();
  }
}

class _ManualEntryForm extends StatefulWidget {
  final Future<void> Function(HotspotCredentials) onCredentials;
  final bool processing;

  const _ManualEntryForm({
    required this.onCredentials,
    required this.processing,
  });

  @override
  State<_ManualEntryForm> createState() => _ManualEntryFormState();
}

class _ManualEntryFormState extends State<_ManualEntryForm> {
  final _ssidController = TextEditingController();
  final _passController = TextEditingController();

  @override
  void dispose() {
    _ssidController.dispose();
    _passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Or enter credentials manually:',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _ssidController,
          decoration: const InputDecoration(
            labelText: 'Network Name (SSID)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _passController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Password',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: widget.processing
              ? null
              : () {
                  final ssid = _ssidController.text.trim();
                  final pass = _passController.text.trim();
                  if (ssid.isEmpty || pass.isEmpty) return;
                  widget.onCredentials(
                    HotspotCredentials(ssid: ssid, passphrase: pass),
                  );
                },
          icon: widget.processing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.wifi),
          label: const Text('Connect'),
        ),
      ],
    );
  }
}
