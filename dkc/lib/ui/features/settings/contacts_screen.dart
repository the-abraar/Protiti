import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../data/repositories/contact_repository.dart';
import '../../../data/services/database_service.dart';
import '../../../data/services/native_sms_service.dart';
import '../../../domain/models/contact.dart';
import '../../../domain/use_cases/trigger_panic.dart';
import '../../core/widgets/explain_permission.dart';

/// The people an SOS text goes to. Lives only in the real vault.
class ContactsScreen extends StatefulWidget {
  final ContactRepository? repository;
  final SmsDispatcher sendSms;

  const ContactsScreen({super.key, this.repository, this.sendSms = dispatchSms});

  /// Neutral on purpose: it also lands in her own Sent messages.
  static const testMessage = 'Test message. Please reply OK if you got this.';

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  late final ContactRepository _repo = widget.repository ?? ContactRepository(DatabaseService());
  List<TrustedContact>? _contacts;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final contacts = await _repo.getAllContacts();
    if (mounted) setState(() => _contacts = contacts);
  }

  Future<void> _edit([TrustedContact? existing]) async {
    final saved = await showDialog<TrustedContact>(
      context: context,
      builder: (_) => _ContactDialog(existing: existing),
    );
    if (saved == null) return;
    await _repo.addContact(saved);
    await _load();
  }

  Future<void> _delete(TrustedContact contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${contact.name}?'),
        content: const Text('They will no longer get your SOS texts.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _repo.deleteContact(contact.id);
    await _load();
  }

  Future<void> _sendTest(TrustedContact contact) async {
    final messenger = ScaffoldMessenger.of(context);
    final needsPermission = Platform.isAndroid && !await NativeSmsService.hasPermission();
    if (!mounted) return;
    if (needsPermission) {
      await explainThenRequest(
        context,
        title: 'Allow sending texts',
        body: 'To text your trusted contacts without opening the Messages app, the phone '
            'will ask to let this app send SMS. It costs a normal text each time. '
            'If you say no, the Messages app opens and you press Send yourself.',
        request: NativeSmsService.requestPermission,
      );
    }
    final result = await widget.sendSms([contact.phone], ContactsScreen.testMessage);
    final status = result.statuses[contact.phone];
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text(switch (status) {
        SmsStatus.sent => 'Test text sent to ${contact.name}.',
        SmsStatus.unconfirmed => 'Messages app opened. Press Send there.',
        _ => 'Not sent. Check the SIM, credit and signal, then try again.',
      }),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final contacts = _contacts;
    return Scaffold(
      appBar: AppBar(title: const Text('Trusted contacts')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add contact'),
      ),
      body: contacts == null
          ? const Center(child: CircularProgressIndicator())
          : contacts.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No trusted contacts yet. Your SOS text goes only to the people you add here. '
                    'Add someone you trust, then send them a test text.',
                  ),
                )
              : ListView(
                  children: [
                    for (final c in contacts)
                      ListTile(
                        title: Text(c.name),
                        subtitle: Text(c.phone),
                        onTap: () => _edit(c),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Send test SMS',
                              icon: const Icon(Icons.sms_outlined),
                              onPressed: () => _sendTest(c),
                            ),
                            IconButton(
                              tooltip: 'Remove',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _delete(c),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
    );
  }
}

class _ContactDialog extends StatefulWidget {
  final TrustedContact? existing;
  const _ContactDialog({this.existing});

  @override
  State<_ContactDialog> createState() => _ContactDialogState();
}

class _ContactDialogState extends State<_ContactDialog> {
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _phone = TextEditingController(text: widget.existing?.phone);
  String? _nameError;
  String? _phoneError;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final phone = TrustedContact.normalizePhone(_phone.text);
    setState(() {
      _nameError = name.isEmpty ? 'Enter a name.' : null;
      _phoneError = phone == null ? 'Enter a Bangladeshi mobile number, like 01712345678.' : null;
    });
    if (name.isEmpty || phone == null) return;
    Navigator.pop(
      context,
      TrustedContact(
        id: widget.existing?.id ?? const Uuid().v4(),
        name: name,
        phone: phone,
        email: '',
        relationship: '',
        isEmergency: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.existing == null ? 'Add contact' : 'Edit contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: InputDecoration(labelText: 'Name', errorText: _nameError),
            ),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: 'Mobile number', errorText: _phoneError),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: _save, child: const Text('Save')),
        ],
      );
}
