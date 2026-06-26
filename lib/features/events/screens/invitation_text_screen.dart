import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../ui/app_form_field.dart';
import '../../../ui/edit_scaffold.dart';
import '../data/event.dart';
import '../data/event_draft.dart';
import '../data/events_providers.dart';
import '../data/guest_invitation.dart';

/// Spec 023 §1.6 — edit the event-level invitation template. Seeded from the
/// event's saved `invitation_text`, or the generated prefill when none is set.
/// Saving persists it on the event; sending an invitation later uses this text
/// (falling back to the same prefill when still empty).
class InvitationTextScreen extends ConsumerStatefulWidget {
  const InvitationTextScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<InvitationTextScreen> createState() =>
      _InvitationTextScreenState();
}

class _InvitationTextScreenState extends ConsumerState<InvitationTextScreen> {
  final _controller = TextEditingController();
  bool _seeded = false;
  bool _dirty = false;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Seed once from the loaded event: the saved template, else the prefill.
  void _seed(Event event) {
    if (_seeded) return;
    final saved = event.invitationText?.trim();
    _controller.text = (saved == null || saved.isEmpty)
        ? composeInvitationPrefill(
            AppLocalizations.of(context),
            Localizations.localeOf(context),
            event,
          )
        : event.invitationText!;
    _seeded = true;
  }

  Future<void> _save(Event event) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final draft = EventDraft.fromEvent(event)
        ..invitationText = _controller.text.trim().isEmpty
            ? null
            : _controller.text.trim();
      await ref.read(eventsRepositoryProvider).updateEvent(event.id, draft);
      ref.invalidate(eventByIdProvider(event.id));
      if (!mounted) return;
      context.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.invitationSaveError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final eventAsync = ref.watch(eventByIdProvider(widget.eventId));
    return eventAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      ),
      error: (_, _) => Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(title: Text(l10n.invitationTextTitle)),
        body: Center(
          child: Text(
            l10n.eventsLoadError,
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ),
      data: (event) {
        _seed(event);
        return EditScaffold(
          title: l10n.invitationTextTitle,
          hasUnsavedChanges: _dirty,
          busy: _saving,
          onSave: _saving ? null : () => _save(event),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Text(
                l10n.invitationTextHelp,
                style: AppTypography.body.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _controller,
                hintText: l10n.invitationTextHint,
                maxLines: 10,
                textInputAction: TextInputAction.newline,
                onChanged: (_) {
                  if (!_dirty) setState(() => _dirty = true);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
