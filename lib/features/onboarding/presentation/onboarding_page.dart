import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:tracr/core/presentation/widgets/user_avatar.dart';
import 'package:tracr/core/theme/theme_provider.dart';
import 'package:tracr/features/auth/data/auth_repository.dart';
import 'package:tracr/features/profile/data/profile_repository.dart';
import 'package:tracr/features/profile/domain/username_validator.dart';

enum _Availability { idle, checking, available, taken }

/// One route, three internal steps — display name, avatar, theme — rather
/// than three routes, so the router's redirect logic (which only knows
/// "onboarding complete or not") doesn't have to model step progress too.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  int _step = 0;

  final _usernameController = TextEditingController();
  Timer? _debounce;
  String? _formatError;
  _Availability _availability = _Availability.idle;

  String? _photoUrl;
  bool _isUploadingAvatar = false;
  String? _avatarError;

  bool _isFinishing = false;
  String? _finishError;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authStateChangesProvider).value;
    final displayName = user?.displayName;
    if (displayName != null && displayName.isNotEmpty) {
      final slug = displayName
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9_]'), '_')
          .replaceAll(RegExp(r'_+'), '_')
          .replaceAll(RegExp(r'^_|_$'), '');
      _usernameController.text = slug.length > 20 ? slug.substring(0, 20) : slug;
      if (_usernameController.text.length >= 3) {
        _onUsernameChanged(_usernameController.text);
      }
    }
    _photoUrl = user?.photoURL;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _usernameController.dispose();
    super.dispose();
  }

  void _onUsernameChanged(String value) {
    _debounce?.cancel();
    final error = usernameValidationError(value);
    setState(() {
      _formatError = error;
      _availability = error == null ? _Availability.checking : _Availability.idle;
    });
    if (error != null) return;

    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final lower = value.trim().toLowerCase();
      final available = await ref.read(profileRepositoryProvider).isUsernameAvailable(lower);
      if (!mounted) return;
      if (lower != _usernameController.text.trim().toLowerCase()) return;
      setState(() => _availability = available ? _Availability.available : _Availability.taken);
    });
  }

  Future<void> _pickAndUploadAvatar() async {
    setState(() => _avatarError = null);
    final XFile? picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final sizeBytes = await picked.length();
    if (sizeBytes > 8 * 1024 * 1024) {
      setState(() => _avatarError = 'That image is too large — pick one under 8MB.');
      return;
    }

    setState(() => _isUploadingAvatar = true);
    try {
      final bytes = await picked.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        setState(() => _avatarError = "Couldn't read that image — try a different file.");
        return;
      }
      final square = img.copyResizeCropSquare(
        decoded,
        size: 512,
        interpolation: img.Interpolation.average,
      );
      final Uint8List jpeg = img.encodeJpg(square, quality: 85);

      final url = await ref.read(profileRepositoryProvider).uploadAvatar(jpeg);
      if (!mounted) return;
      setState(() => _photoUrl = url);
    } catch (e) {
      if (!mounted) return;
      setState(() => _avatarError = e.toString().replaceAll(RegExp(r'\[.*\]'), '').trim());
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _finish() async {
    setState(() {
      _isFinishing = true;
      _finishError = null;
    });
    try {
      await ref.read(profileRepositoryProvider).claimUsernameAndCreateProfile(
            username: _usernameController.text.trim(),
            usernameLower: _usernameController.text.trim().toLowerCase(),
            photoUrl: _photoUrl,
          );
      // On success the router's redirect logic takes over once
      // currentUserProfileProvider emits the new profile — no navigation
      // call needed here.
    } on UsernameTakenException {
      if (!mounted) return;
      setState(() {
        _step = 0;
        _availability = _Availability.taken;
        _isFinishing = false;
      });
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _finishError = e.toString().replaceAll(RegExp(r'\[.*\]'), '').trim();
        _isFinishing = false;
      });
      return;
    }
    if (mounted) setState(() => _isFinishing = false);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = ShadTheme.of(context).textTheme;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Step ${_step + 1} of 3', style: textTheme.small),
                const Gap(8),
                switch (_step) {
                  0 => _buildNameStep(textTheme),
                  1 => _buildAvatarStep(textTheme),
                  _ => _buildThemeStep(textTheme),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNameStep(ShadTextTheme textTheme) {
    final canProceed = _availability == _Availability.available;

    String? helperText;
    Color? helperColor;
    switch (_availability) {
      case _Availability.idle:
        helperText = _formatError;
        helperColor = Colors.redAccent;
        break;
      case _Availability.checking:
        helperText = 'Checking availability...';
        break;
      case _Availability.available:
        helperText = 'Available';
        helperColor = Colors.green;
        break;
      case _Availability.taken:
        helperText = 'That name is taken.';
        helperColor = Colors.redAccent;
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Choose a display name', style: textTheme.h3),
        const Gap(8),
        Text(
          "This is how you'll appear in tracr. It must be unique.",
          style: textTheme.p,
        ),
        const Gap(20),
        ShadInput(
          controller: _usernameController,
          placeholder: const Text('display_name'),
          onChanged: _onUsernameChanged,
        ),
        if (helperText != null) ...[
          const Gap(8),
          Text(helperText, style: textTheme.small.copyWith(color: helperColor)),
        ],
        const Gap(20),
        ShadButton(
          width: double.infinity,
          onPressed: canProceed ? () => setState(() => _step = 1) : null,
          child: const Text('Next'),
        ),
      ],
    );
  }

  Widget _buildAvatarStep(ShadTextTheme textTheme) {
    final googlePhotoUrl = ref.read(authStateChangesProvider).value?.photoURL;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Add an avatar', style: textTheme.h3),
        const Gap(8),
        Text('Optional — you can skip this and use your initials instead.', style: textTheme.p),
        const Gap(20),
        Center(
          child: UserAvatar(
            username: _usernameController.text,
            photoUrl: _photoUrl,
            radius: 48,
          ),
        ),
        const Gap(20),
        ShadButton.outline(
          width: double.infinity,
          onPressed: _isUploadingAvatar ? null : _pickAndUploadAvatar,
          child: Text(_isUploadingAvatar ? 'Uploading...' : 'Upload a photo'),
        ),
        if (googlePhotoUrl != null && _photoUrl != googlePhotoUrl) ...[
          const Gap(12),
          ShadButton.ghost(
            width: double.infinity,
            onPressed: () => setState(() => _photoUrl = googlePhotoUrl),
            child: const Text('Use my Google photo'),
          ),
        ],
        if (_avatarError != null) ...[
          const Gap(12),
          Text(_avatarError!, style: textTheme.small.copyWith(color: Colors.redAccent)),
        ],
        const Gap(20),
        ShadButton(
          width: double.infinity,
          onPressed: () => setState(() => _step = 2),
          child: Text(_photoUrl == null ? 'Skip' : 'Next'),
        ),
        const Gap(8),
        ShadButton.ghost(
          width: double.infinity,
          onPressed: () => setState(() => _step = 0),
          child: const Text('Back'),
        ),
      ],
    );
  }

  Widget _buildThemeStep(ShadTextTheme textTheme) {
    final currentMode = ref.watch(themeModeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Pick a theme', style: textTheme.h3),
        const Gap(8),
        Text('You can change this later.', style: textTheme.p),
        const Gap(20),
        _ThemeOption(
          label: 'Light',
          icon: Icons.light_mode_outlined,
          selected: currentMode == ThemeMode.light,
          onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light),
        ),
        const Gap(12),
        _ThemeOption(
          label: 'Dark',
          icon: Icons.dark_mode_outlined,
          selected: currentMode == ThemeMode.dark,
          onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark),
        ),
        const Gap(12),
        _ThemeOption(
          label: 'System',
          icon: Icons.settings_suggest_outlined,
          selected: currentMode == ThemeMode.system,
          onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.system),
        ),
        if (_finishError != null) ...[
          const Gap(16),
          Text(_finishError!, style: textTheme.small.copyWith(color: Colors.redAccent)),
        ],
        const Gap(20),
        ShadButton(
          width: double.infinity,
          onPressed: _isFinishing ? null : _finish,
          child: Text(_isFinishing ? 'Finishing...' : 'Finish'),
        ),
        const Gap(8),
        ShadButton.ghost(
          width: double.infinity,
          onPressed: () => setState(() => _step = 1),
          child: const Text('Back'),
        ),
      ],
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: ShadCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: ShadBorder.fromBorderSide(
          ShadBorderSide(
            color: selected ? theme.colorScheme.primary : theme.colorScheme.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20),
            const Gap(12),
            Text(label, style: theme.textTheme.p),
            const Spacer(),
            if (selected) Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 20),
          ],
        ),
      ),
    );
  }
}
