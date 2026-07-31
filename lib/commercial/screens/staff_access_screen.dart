import 'package:flutter/material.dart';

import '../../core/app_constants.dart';
import '../../state/app_state.dart';
import '../../widgets/feedback.dart';

class StaffAccessScreen extends StatefulWidget {
  const StaffAccessScreen({super.key});

  @override
  State<StaffAccessScreen> createState() => _StaffAccessScreenState();
}

class _StaffAccessScreenState extends State<StaffAccessScreen> {
  final name = TextEditingController();
  final username = TextEditingController();
  final pin = TextEditingController();
  bool busy = false;
  bool obscure = true;

  @override
  void dispose() {
    name.dispose();
    username.dispose();
    pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final setup = state.requiresOwnerSetup;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5FB),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 470),
            child: Card(
              elevation: 10,
              shadowColor: const Color(0x220F2A5A),
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(
                            'assets/branding/airmonlink_business_manager_logo.png',
                            width: 76,
                            height: 76,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        AppConstants.appName,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: const Color(0xFF0F2A5A),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        setup
                            ? 'Create the protected owner account. This is required before staff, permissions and audit controls can be used.'
                            : 'Sign in with your staff username and PIN.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF5C6B7A)),
                      ),
                      const SizedBox(height: 24),
                      if (setup) ...[
                        TextField(
                          controller: name,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.name],
                          decoration: const InputDecoration(
                            labelText: 'Owner name',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      TextField(
                        controller: username,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.username],
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: pin,
                        obscureText: obscure,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onSubmitted: (_) => _submit(state),
                        decoration: InputDecoration(
                          labelText: setup ? 'Create PIN' : 'PIN',
                          helperText: setup ? 'Use at least four digits or characters.' : null,
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: obscure ? 'Show PIN' : 'Hide PIN',
                            onPressed: () => setState(() => obscure = !obscure),
                            icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      FilledButton.icon(
                        onPressed: busy ? null : () => _submit(state),
                        icon: busy
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(setup ? Icons.verified_user_outlined : Icons.login),
                        label: Text(setup ? 'Create owner account' : 'Sign in'),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Staff PINs are stored as salted password hashes. Failed sign-ins are rate-limited and audited.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: Color(0xFF667085)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit(AppState state) async {
    if (username.text.trim().isEmpty || pin.text.length < 4) {
      showFailure(context, 'Enter a username and a PIN of at least four characters.');
      return;
    }
    if (state.requiresOwnerSetup && name.text.trim().isEmpty) {
      showFailure(context, 'Owner name is required.');
      return;
    }
    setState(() => busy = true);
    try {
      if (state.requiresOwnerSetup) {
        await state.createInitialOwner(
          name: name.text.trim(),
          username: username.text.trim(),
          pin: pin.text,
        );
      } else {
        await state.login(username: username.text.trim(), pin: pin.text);
      }
    } catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}
