import 'package:custom_tv_text_field/custom_tv_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/repositories/session_repository.dart';
import '../../../data/services/spesh_profile_service.dart';
import '../../../util/platform_detection.dart';
import '../../widgets/spesh_profile_avatar.dart';

class SpeshProfilesScreen extends StatefulWidget {
  const SpeshProfilesScreen({super.key});
  @override
  State<SpeshProfilesScreen> createState() => _SpeshProfilesScreenState();
}

class _SpeshProfilesScreenState extends State<SpeshProfilesScreen> {
  final _session = GetIt.instance<SessionRepository>();
  late final _api = _session.createSpeshProfilesApi();
  List<SpeshViewingProfile>? _profiles;
  String? _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final profiles = await _api.list();
      if (mounted)
        setState(() {
          _profiles = profiles;
        });
    } on SpeshProfilesUnavailable {
      if (mounted)
        setState(() {
          _error = 'Viewing profiles require an updated SpeshTV Core plugin. You can continue with your original account.';
        });
    } catch (_) {
      if (mounted)
        setState(
          () => _error =
              'Could not load profiles. Check the server connection and retry.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _select(SpeshViewingProfile profile) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _session.selectSpeshProfile(profile, _api);
      if (mounted) context.go(_session.takeProfileDestination());
    } catch (_) {
      if (mounted)
        setState(
          () => _error = 'Could not switch profiles. Your saved account is unchanged. Please retry.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(SpeshViewingProfile? profile) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ProfileEditor(api: _api, profile: profile),
    );
    if (saved == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy && !_session.needsSpeshProfile,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('SpeshTV'),
        automaticallyImplyLeading: false,
        actions: [
          if (!_session.needsSpeshProfile)
            TextButton(
              onPressed: _busy ? null : () => context.go('/home'),
              child: const Text('Back'),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Who’s watching?',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Each profile has its own viewing progress and favorites.',
                  ),
                  const SizedBox(height: 28),
                  if (_profiles != null)
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 24,
                      runSpacing: 24,
                      children: [
                        for (final profile in _profiles!)
                          SizedBox(
                            width: 160,
                            child: Column(
                              children: [
                                FilledButton(
                                  autofocus:
                                      profile.id ==
                                      (_session.selectedSpeshProfileId ??
                                          'main'),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.all(8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  onPressed: _busy
                                      ? null
                                      : () => _select(profile),
                                  child: Column(
                                    children: [
                                      SpeshProfileAvatar(
                                        avatar: profile.avatar,
                                        size: 112,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        profile.name,
                                        maxLines: 2,
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _edit(profile),
                                  child: const Text('Edit profile'),
                                ),
                              ],
                            ),
                          ),
                        if (_profiles!.length < 3)
                          SizedBox(
                            width: 160,
                            child: OutlinedButton(
                              onPressed: _busy ? null : () => _edit(null),
                              child: const Padding(
                                padding: EdgeInsets.all(24),
                                child: Column(
                                  children: [
                                    Icon(Icons.add, size: 54),
                                    Text('Add profile'),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_error!, textAlign: TextAlign.center),
                    ),
                  if (_error != null)
                    Wrap(
                      spacing: 16,
                      children: [
                        TextButton(
                          onPressed: _busy ? null : _load,
                          child: const Text('Retry'),
                        ),
                        FilledButton(
                          onPressed: _busy
                              ? null
                              : () async {
                                  await _session.continueWithoutSpeshProfiles();
                                  if (context.mounted)
                                    context.go(
                                      _session.takeProfileDestination(),
                                    );
                                },
                          child: const Text('Continue with original account'),
                        ),
                      ],
                    ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            await _session.destroyCurrentSession();
                            if (context.mounted) context.go('/');
                          },
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _ProfileEditor extends StatefulWidget {
  const _ProfileEditor({required this.api, this.profile});
  final SpeshViewingProfilesApi api;
  final SpeshViewingProfile? profile;
  @override
  State<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<_ProfileEditor> {
  late final _name = TextEditingController(text: widget.profile?.name ?? '');
  late String _avatar = widget.profile?.avatar ?? 'blue';
  final _nameFocus = FocusNode();
  final _tvKey = GlobalKey<CustomTVTextFieldState>();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    try {
      SpeshViewingProfilesApi.validate(_name.text, _avatar);
    } catch (_) {
      setState(() => _error = 'Enter a name of 1–24 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.save(
        profile: widget.profile,
        name: _name.text,
        avatar: _avatar,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Could not save the profile. Please retry.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text(widget.profile == null ? 'Add profile' : 'Edit profile'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (PlatformDetection.isTV)
                Focus(
                  focusNode: _nameFocus,
                  autofocus: true,
                  onKeyEvent: (_, event) {
                    if (event is KeyDownEvent &&
                        (event.logicalKey == LogicalKeyboardKey.select ||
                            event.logicalKey == LogicalKeyboardKey.enter)) {
                      _tvKey.currentState?.openKeyboard();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: ListenableBuilder(
                    listenable: _nameFocus,
                    builder: (_, _) => CustomTVTextField(
                      key: _tvKey,
                      controller: _name,
                      hint: 'Profile name',
                      isFocused: _nameFocus.hasFocus,
                      popParentOnKeyboardClose: false,
                    ),
                  ),
                )
              else
                TextField(
                  controller: _name,
                  autofocus: true,
                  maxLength: 24,
                  enabled: !_busy,
                  decoration: const InputDecoration(labelText: 'Profile name'),
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final avatar in speshProfileAvatars)
                    Semantics(
                      label: '$avatar avatar',
                      selected: avatar == _avatar,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: avatar == _avatar
                                ? Colors.white
                                : Colors.transparent,
                            width: 3,
                          ),
                          padding: const EdgeInsets.all(4),
                        ),
                        onPressed: _busy
                            ? null
                            : () => setState(() => _avatar = avatar),
                        child: SpeshProfileAvatar(avatar: avatar, size: 60),
                      ),
                    ),
                ],
              ),
              if (_error != null) Text(_error!),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Saving…' : 'Save'),
        ),
      ],
    ),
  );
}
