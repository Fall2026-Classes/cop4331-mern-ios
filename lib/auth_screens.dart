import 'package:flutter/material.dart';

import 'api.dart';
import 'diary_screen.dart';
import 'widgets.dart';

/// Lets the user point the app at a different server (e.g. http://192.168.1.20:5000).
Future<void> showServerDialog(BuildContext context) async {
  final ctrl = TextEditingController(text: Api.baseUrl);
  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Server'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(hintText: 'https://mern.fire-line.tech'),
          ),
          const SizedBox(height: 8),
          const Text('Address of the ReelTalk web server (it serves the /api routes).',
              style: TextStyle(color: kMuted, fontSize: 12)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            ctrl.text = Api.defaultBaseUrl;
          },
          child: const Text('Default'),
        ),
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
      ],
    ),
  );
  if (saved == true) await Api.setBaseUrl(ctrl.text);
}

class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kBg,
        actions: [
          IconButton(
            tooltip: 'Server',
            icon: const Icon(Icons.dns_outlined),
            onPressed: () => showServerDialog(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: kBorder),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Brand(size: 32),
                    const SizedBox(height: 4),
                    const Text('Rate and review every movie and show you watch.', style: TextStyle(color: kMuted)),
                    const SizedBox(height: 20),
                    Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    ...children,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text, {this.error = true});
  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final color = error ? kDanger : kAccent;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: color)),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.login = '', this.justRegistered = false});
  final String login;
  final bool justRegistered;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  late final _login = TextEditingController(text: widget.login);
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Api.login(_login.text.trim(), _password.text);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DiaryScreen()),
        (_) => false,
      );
    } on ApiException catch (e) {
      setState(() {
        _busy = false;
        _error = e.status == 401 || e.status == 0
            ? (e.status == 0 ? e.message : 'The username or password is incorrect.')
            : 'Login failed: ${e.message}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: 'Log in',
      children: [
        if (widget.justRegistered && _error == null) const _Message('Account created. You can log in now.', error: false),
        if (_error != null) _Message(_error!),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _login,
                decoration: const InputDecoration(labelText: 'Username'),
                autocorrect: false,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _submit(),
                validator: (v) => (v ?? '').isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(_busy ? 'Logging in...' : 'Log in'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
          child: const Text("Don't have an account? Register"),
        ),
      ],
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _login = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final login = _login.text.trim();
      await Api.register(
        firstName: _first.text.trim(),
        lastName: _last.text.trim(),
        login: login,
        password: _password.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => LoginScreen(login: login, justRegistered: true)),
        (_) => false,
      );
    } on ApiException catch (e) {
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  String? _required(String? v) => (v ?? '').trim().isEmpty ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: 'Create an account',
      children: [
        if (_error != null) _Message(_error!),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _first,
                    decoration: const InputDecoration(labelText: 'First name'),
                    textInputAction: TextInputAction.next,
                    validator: _required,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _last,
                    decoration: const InputDecoration(labelText: 'Last name'),
                    textInputAction: TextInputAction.next,
                    validator: _required,
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              TextFormField(
                controller: _login,
                decoration: const InputDecoration(labelText: 'Username (3-30 characters)'),
                autocorrect: false,
                textInputAction: TextInputAction.next,
                validator: (v) {
                  final s = (v ?? '').trim();
                  return s.length < 3 || s.length > 30 ? 'Must be 3-30 characters' : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                decoration: const InputDecoration(labelText: 'Password (6+ characters)'),
                obscureText: true,
                textInputAction: TextInputAction.next,
                validator: (v) => (v ?? '').length < 6 ? 'At least 6 characters' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirm,
                decoration: const InputDecoration(labelText: 'Confirm password'),
                obscureText: true,
                onFieldSubmitted: (_) => _submit(),
                validator: (v) => v != _password.text ? 'Passwords do not match.' : null,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(_busy ? 'Creating...' : 'Register'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Already have an account? Log in'),
        ),
      ],
    );
  }
}
