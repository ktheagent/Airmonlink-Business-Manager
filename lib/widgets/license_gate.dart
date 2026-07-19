import 'package:flutter/material.dart';

class LicenseGate extends StatelessWidget {
  const LicenseGate({required this.child, required this.restricted, super.key});

  final Widget child;
  final bool restricted;

  @override
  Widget build(BuildContext context) {
    if (!restricted) return child;
    return Stack(
      children: [
        Opacity(opacity: 0.4, child: child),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: const [
                  Icon(Icons.lock_outline),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Restricted mode is active. Existing records remain available, but new changes are temporarily blocked.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
