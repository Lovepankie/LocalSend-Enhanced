import 'package:flutter/material.dart';
import 'package:localsend_app/provider/network/network_error_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// Displays the latest network error as a dismissible colored banner.
/// Wraps its [child] — place it at the top of a page body.
class NetworkErrorBanner extends StatelessWidget {
  final Widget child;

  const NetworkErrorBanner({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    final errors = context.watch(networkErrorProvider).errors;

    if (errors.isEmpty) return child;

    final error = errors.first;
    final isWarning = error.severity == NetworkErrorSeverity.warning;
    final bgColor = isWarning
        ? Theme.of(context).colorScheme.tertiaryContainer
        : Theme.of(context).colorScheme.errorContainer;
    final fgColor = isWarning
        ? Theme.of(context).colorScheme.onTertiaryContainer
        : Theme.of(context).colorScheme.onErrorContainer;

    return Column(
      children: [
        Material(
          color: bgColor,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Icon(
                    isWarning ? Icons.warning_amber_rounded : Icons.error_outline_rounded,
                    color: fgColor,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      error.message,
                      style: TextStyle(color: fgColor, fontSize: 13),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: fgColor, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => context.notifier(networkErrorProvider).dismissFirst(),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
