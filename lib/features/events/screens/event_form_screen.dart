import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../ui/app_form_field.dart';
import '../../../ui/primary_button.dart';
import '../../../ui/segmented_choice.dart';
import '../../../ui/stepper_field.dart';
import '../data/event.dart';
import '../data/event_draft.dart';
import '../data/events_providers.dart';
import '../widgets/event_formatters.dart';

/// Create / edit form for an event (spec 003 §2.3).
///
/// The same widget renders both modes. In edit mode the caller usually
/// hands the [initialEvent] through `extra` (the detail screen has it
/// already); if it doesn't, the wrapper fetches the row before rendering
/// the form so deep links / refreshes still work.
class EventFormScreen extends ConsumerWidget {
  const EventFormScreen({super.key, this.eventId, this.initialEvent});

  final String? eventId;
  final Event? initialEvent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (eventId == null) {
      return const _EventForm();
    }
    if (initialEvent != null) {
      return _EventForm(eventId: eventId, initial: initialEvent);
    }
    final fetched = ref.watch(eventByIdProvider(eventId!));
    return fetched.when(
      data: (event) => _EventForm(eventId: eventId, initial: event),
      loading: () => const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      ),
      error: (_, _) => Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(),
        body: Center(
          child: Text(
            AppLocalizations.of(context).eventsLoadError,
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _EventForm extends ConsumerStatefulWidget {
  const _EventForm({this.eventId, this.initial});

  final String? eventId;
  final Event? initial;

  bool get isEditing => eventId != null;

  @override
  ConsumerState<_EventForm> createState() => _EventFormState();
}

class _EventFormState extends ConsumerState<_EventForm> {
  late final TextEditingController _titleController;
  late final TextEditingController _locationController;
  late final TextEditingController _notesController;
  late EventDraft _draft;

  bool _saving = false;
  bool _deleting = false;
  String? _titleError;
  // Whether the user already attempted to save; used to gate re-validation
  // on subsequent edits without flashing red text on first keystroke.
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _draft = widget.initial != null
        ? EventDraft.fromEvent(widget.initial!)
        : EventDraft.empty();
    _titleController = TextEditingController(text: _draft.title);
    _locationController = TextEditingController(
      text: _draft.locationName ?? '',
    );
    _notesController = TextEditingController(text: _draft.notes ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _busy => _saving || _deleting;

  String? _validateTitle(AppLocalizations l10n, String value) {
    if (value.trim().isEmpty) return l10n.fieldTitleRequired;
    return null;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _draft.eventDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
      builder: _pickerTheme,
    );
    if (picked != null) {
      setState(() => _draft.eventDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _draft.eventTime ?? const TimeOfDay(hour: 14, minute: 0),
      builder: _pickerTheme,
    );
    if (picked != null) {
      setState(() => _draft.eventTime = picked);
    }
  }

  Widget _pickerTheme(BuildContext context, Widget? child) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: const ColorScheme.light(
          primary: AppColors.accentSecondary,
          onPrimary: AppColors.onAccent,
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary,
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.accent,
            textStyle: AppTypography.button.copyWith(color: AppColors.accent),
          ),
        ),
      ),
      child: child!,
    );
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _submitted = true);
    _draft.title = _titleController.text;
    _draft.locationName = _locationController.text;
    _draft.notes = _notesController.text;

    final titleError = _validateTitle(l10n, _draft.title);
    if (titleError != null) {
      setState(() => _titleError = titleError);
      return;
    }
    setState(() {
      _titleError = null;
      _saving = true;
    });

    final repo = ref.read(eventsRepositoryProvider);

    try {
      if (widget.isEditing) {
        await repo.updateEvent(widget.eventId!, _draft);
      } else {
        final groupId = await ref.read(currentGroupIdProvider.future);
        await repo.createEvent(_draft, groupId: groupId);
      }
      ref.invalidate(eventsListProvider);
      ref.invalidate(eventReadinessProvider);
      if (widget.eventId != null) {
        ref.invalidate(eventByIdProvider(widget.eventId!));
      }
      if (!mounted) return;
      context.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.saveError)));
    }
  }

  Future<void> _confirmDelete() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: Text(
            l10n.deleteEventConfirmTitle,
            style: AppTypography.sectionTitle,
          ),
          content: Text(
            l10n.deleteEventConfirmBody,
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                l10n.cancelAction,
                style: AppTypography.button.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                l10n.deleteEventConfirmButton,
                style: AppTypography.button.copyWith(color: AppColors.danger),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    await _delete();
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _deleting = true);
    try {
      await ref.read(eventsRepositoryProvider).deleteEvent(widget.eventId!);
      ref.invalidate(eventsListProvider);
      ref.invalidate(eventByIdProvider(widget.eventId!));
      if (!mounted) return;
      // Pop the form and the detail screen so the user lands on the list.
      context.go('/');
    } catch (_) {
      if (!mounted) return;
      setState(() => _deleting = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.saveError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(
          widget.isEditing
              ? l10n.eventEditScreenTitle
              : l10n.eventNewScreenTitle,
          style: AppTypography.sectionTitle,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: l10n.backAction,
          onPressed: _busy ? null : () => context.pop(),
        ),
        actions: [
          if (widget.isEditing)
            PopupMenuButton<_OverflowAction>(
              icon: const Icon(Icons.more_vert),
              tooltip: l10n.moreActionsLabel,
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (action) {
                switch (action) {
                  case _OverflowAction.delete:
                    _confirmDelete();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _OverflowAction.delete,
                  child: Text(
                    l10n.deleteAction,
                    style: AppTypography.body.copyWith(color: AppColors.danger),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            FieldLabel(
              label: l10n.fieldTitleLabel,
              child: AppTextField(
                controller: _titleController,
                hintText: l10n.fieldTitleHint,
                onChanged: (value) {
                  if (!_submitted) return;
                  setState(() {
                    _titleError = _validateTitle(l10n, value);
                  });
                },
              ),
            ),
            if (_titleError != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _titleError!,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.danger,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            FieldLabel(
              label: l10n.fieldTypeLabel,
              child: SegmentedChoice<EventType>(
                value: _draft.type,
                onChanged: (v) => setState(() => _draft.type = v),
                options: [
                  for (final t in EventType.values)
                    SegmentedChoiceOption(t, eventTypeLabel(l10n, t)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FieldLabel(
              label: l10n.fieldFormatLabel,
              child: SegmentedChoice<EventFormat>(
                value: _draft.format,
                onChanged: (v) => setState(() => _draft.format = v),
                options: [
                  for (final f in EventFormat.values)
                    SegmentedChoiceOption(f, eventFormatLabel(l10n, f)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fixes §2.1: the earlier fixed proportion overcorrected — at
                // 3:1 the Date had excess space and the Time ("21:00") wrapped.
                // Instead the Time field is sized intrinsically to its content
                // (HH:MM plus the clear icon) and the Date takes the remaining
                // width, so neither wraps regardless of the month name's length.
                Expanded(
                  child: FieldLabel(
                    label: l10n.fieldDateLabel,
                    child: FormFieldTile(
                      onTap: _pickDate,
                      placeholder: l10n.fieldDateHint,
                      value: _draft.eventDate == null
                          ? null
                          : DateFormat.yMMMd(
                              locale.toLanguageTag(),
                            ).format(_draft.eventDate!),
                      onClear: _draft.eventDate == null
                          ? null
                          : () => setState(() => _draft.eventDate = null),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IntrinsicWidth(
                  child: FieldLabel(
                    label: l10n.fieldTimeLabel,
                    child: FormFieldTile(
                      onTap: _pickTime,
                      placeholder: l10n.fieldTimeHint,
                      value: _draft.eventTime == null
                          ? null
                          : _formatTime(_draft.eventTime!, locale),
                      onClear: _draft.eventTime == null
                          ? null
                          : () => setState(() => _draft.eventTime = null),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FieldLabel(
              label: l10n.fieldGuestCountLabel,
              child: StepperField(
                value: _draft.guestCount,
                onChanged: (v) => setState(() => _draft.guestCount = v),
              ),
            ),
            const SizedBox(height: 16),
            FieldLabel(
              label: l10n.fieldLocationLabel,
              child: AppTextField(
                controller: _locationController,
                hintText: l10n.fieldLocationHint,
              ),
            ),
            const SizedBox(height: 16),
            FieldLabel(
              label: l10n.fieldNotesLabel,
              child: AppTextField(
                controller: _notesController,
                hintText: l10n.fieldNotesHint,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: const BoxDecoration(
            color: AppColors.bg,
            border: Border(top: BorderSide(color: AppColors.border, width: 1)),
          ),
          child: PrimaryButton(
            label: l10n.saveAction,
            icon: Icons.check,
            onPressed: _busy ? null : _save,
          ),
        ),
      ),
    );
  }

  String _formatTime(TimeOfDay value, Locale locale) {
    final dt = DateTime(2000, 1, 1, value.hour, value.minute);
    return DateFormat.Hm(locale.toLanguageTag()).format(dt);
  }
}

enum _OverflowAction { delete }
