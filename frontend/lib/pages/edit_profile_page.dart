import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/user.dart';
import '../services/api_service.dart';
import '../utils/error_helpers.dart';
import '../utils/image_helpers.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key, required this.user});

  final User user;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _usernameCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _surnameCtrl;
  late final TextEditingController _bioCtrl;
  DateTime? _birthdate;

  Uint8List? _pickedImageBytes;
  bool _saving = false;
  String? _error;
  late String _allowDmsFrom;

  String? get _userType => widget.user.userType;

  bool get _hasNameFields =>
      _userType == 'Climber' || _userType == 'FacilityOwner' || _userType == null;

  bool get _hasBirthdate => _userType == 'Climber' || _userType == null;

  @override
  void initState() {
    super.initState();
    _usernameCtrl = TextEditingController(text: widget.user.username);
    _nameCtrl = TextEditingController(text: widget.user.name ?? '');
    _surnameCtrl = TextEditingController(text: widget.user.surname ?? '');
    _bioCtrl = TextEditingController(text: widget.user.bio ?? '');
    _birthdate = widget.user.birthdate;
    _allowDmsFrom = widget.user.allowDmsFrom;
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _nameCtrl.dispose();
    _surnameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await _showImageSourceDialog();
    if (source == null) return;

    final XFile? file = await ImagePicker().pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();
    setState(() => _pickedImageBytes = bytes);
  }

  Future<ImageSource?> _showImageSourceDialog() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Photo library'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickBirthdate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthdate ?? DateTime(now.year - 18),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) setState(() => _birthdate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final updates = <String, dynamic>{};

      final newUsername = _usernameCtrl.text.trim();
      if (newUsername != widget.user.username) updates['username'] = newUsername;

      if (_pickedImageBytes != null) {
        updates['avatar'] =
            'data:image/jpeg;base64,${base64Encode(_pickedImageBytes!)}';
      }

      if (_hasNameFields) {
        final newName = _nameCtrl.text.trim();
        if (newName != (widget.user.name ?? '')) updates['name'] = newName;

        final newSurname = _surnameCtrl.text.trim();
        if (newSurname != (widget.user.surname ?? '')) updates['surname'] = newSurname;
      }

      final newBio = _bioCtrl.text.trim();
      if (newBio != (widget.user.bio ?? '')) updates['bio'] = newBio;

      if (_userType == 'Climber' && _allowDmsFrom != widget.user.allowDmsFrom) {
        updates['allowDmsFrom'] = _allowDmsFrom;
      }

      if (_hasBirthdate && _birthdate != widget.user.birthdate) {
        updates['birthdate'] = _birthdate?.toIso8601String();
      }

      if (updates.isEmpty) {
        if (mounted) Navigator.of(context).pop();
        return;
      }

      final updated = await ApiService().updateCurrentUserProfile(updates);
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = errorSummary(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit profile'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Save'),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          children: [
            _AvatarPicker(
              existingUrl: widget.user.profilePictureUrl,
              pickedBytes: _pickedImageBytes,
              username: widget.user.username,
              onTap: _saving ? null : _pickImage,
            ),
            const SizedBox(height: 28),
            if (_error != null) ...[
              _ErrorBanner(message: _error!),
              const SizedBox(height: 16),
            ],
            Text(
              'Account',
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: colorScheme.primary),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _usernameCtrl,
              decoration: const InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
              textInputAction: TextInputAction.next,
              validator: (v) {
                final s = v?.trim() ?? '';
                if (s.length < 3) return 'At least 3 characters';
                if (s.length > 30) return 'At most 30 characters';
                return null;
              },
            ),
            const SizedBox(height: 28),
            Text(
              'Personal info',
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: colorScheme.primary),
            ),
            const SizedBox(height: 10),
            if (_hasNameFields) ...[
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'First name',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _surnameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Last name',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],
            if (_hasBirthdate) ...[
              InkWell(
                onTap: _pickBirthdate,
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date of birth',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(
                    _birthdate != null
                        ? '${_birthdate!.day.toString().padLeft(2, '0')}/${_birthdate!.month.toString().padLeft(2, '0')}/${_birthdate!.year}'
                        : 'Not set',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: _birthdate != null
                          ? null
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            TextFormField(
              controller: _bioCtrl,
              decoration: const InputDecoration(
                labelText: 'Bio',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              maxLength: 200,
              buildCounter:
                  (_, {required currentLength, required isFocused, maxLength}) =>
                      null,
              onChanged: (_) => setState(() {}),
              validator: (v) {
                if ((v?.length ?? 0) > 200) return 'Max 200 characters';
                return null;
              },
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${_bioCtrl.text.length}/200',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ),
            if (_userType == 'Climber') ...[
              const SizedBox(height: 20),
              Text(
                'Privacy',
                style: theme.textTheme.titleSmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _allowDmsFrom,
                decoration: const InputDecoration(
                  labelText: 'Who can send you messages',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'everyone', child: Text('Everyone')),
                  DropdownMenuItem(
                      value: 'followers',
                      child: Text('People I follow')),
                  DropdownMenuItem(value: 'nobody', child: Text('Nobody')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _allowDmsFrom = v);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({
    required this.username,
    required this.existingUrl,
    required this.pickedBytes,
    required this.onTap,
  });

  final String username;
  final String? existingUrl;
  final Uint8List? pickedBytes;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';

    final ImageProvider? image = pickedBytes != null
        ? MemoryImage(pickedBytes!)
        : avatarImageProvider(existingUrl);

    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          children: [
            CircleAvatar(
              radius: 52,
              backgroundColor: colorScheme.primaryContainer,
              backgroundImage: image,
              child: image == null
                  ? Text(
                      initial,
                      style: Theme.of(context)
                          .textTheme
                          .displaySmall
                          ?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                    )
                  : null,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: colorScheme.surface, width: 2),
                ),
                padding: const EdgeInsets.all(6),
                child: Icon(Icons.camera_alt,
                    size: 16, color: colorScheme.onPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colorScheme.onErrorContainer, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
