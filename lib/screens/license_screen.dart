import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../licensing/license_service.dart';
import '../licensing/license_status.dart';

class LicenseScreen extends StatefulWidget {
  const LicenseScreen({super.key, this.service});

  final LicenseService? service;

  @override
  State<LicenseScreen> createState() => _LicenseScreenState();
}

class _LicenseScreenState extends State<LicenseScreen> {
  late final LicenseService _service = widget.service ?? LicenseService();
  final TextEditingController _licenseController = TextEditingController();
  LicenseStatus? _status;
  bool _loading = false;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _licenseController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final status = await _service.initialize(
        businessName: 'Airmonlink Business Manager',
      );
      if (!mounted) return;
      setState(() {
        _status = status;
        _message = status.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _status = const LicenseStatus(
          state: LicenseState.invalid,
          plan: 'trial',
          message: 'Unable to load licence state.',
          isRestricted: false,
        );
        _message = 'Unable to load licence state right now.';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _activate() async {
    final key = _licenseController.text.trim();
    if (key.isEmpty) {
      setState(() => _message = 'Enter a licence key to activate the app.');
      return;
    }

    setState(() => _loading = true);
    try {
      final license = await _service.activateLicense(
        licenseKey: key,
        businessName: 'Airmonlink Business Manager',
      );
      if (!mounted) return;
      setState(() {
        _message = license == null
            ? 'Activation completed.'
            : 'Licence activated for ${license.customer}.';
      });
      await _reload();
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _message =
            'Activation failed. Please verify the licence key and try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _startTrial() async {
    setState(() => _loading = true);
    try {
      await _service.registerTrial();
      await _reload();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openSupport() async {
    final uri = Uri.parse('https://www.airmonlink.com/contact');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      setState(() => _message = 'Unable to open the support page right now.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.workspace_premium,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Commercial licence control',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Activate a paid licence, stay on the premium experience, or continue with the 14-day trial.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_loading)
                    const LinearProgressIndicator()
                  else if (status != null)
                    _StatusPanel(status: status, message: _message)
                  else
                    const Text('Loading licence status...'),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _licenseController,
                    decoration: const InputDecoration(
                      labelText: 'Licence key',
                      hintText: 'Enter your activation key',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: _loading ? null : _activate,
                        icon: const Icon(Icons.verified_user_outlined),
                        label: const Text('Activate licence'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _loading ? null : _startTrial,
                        icon: const Icon(Icons.timer_outlined),
                        label: const Text('Start trial'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _openSupport,
                    icon: const Icon(Icons.support_agent_outlined),
                    label: const Text('Contact support'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.status, required this.message});

  final LicenseStatus status;
  final String message;

  @override
  Widget build(BuildContext context) {
    final color = switch (status.state) {
      LicenseState.active => Colors.green,
      LicenseState.gracePeriod => Colors.orange,
      LicenseState.trial => Colors.blue,
      LicenseState.expired => Colors.red,
      LicenseState.suspended => Colors.orange,
      LicenseState.invalid => Colors.red,
      LicenseState.activationRequired => Colors.amber,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.circle, color: color, size: 12),
              const SizedBox(width: 8),
              Text(
                status.state.name.toUpperCase(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(message),
          const SizedBox(height: 8),
          Text('Plan: ${status.plan}'),
          if (status.isRestricted)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Some premium features are restricted until the licence is active.',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
        ],
      ),
    );
  }
}
