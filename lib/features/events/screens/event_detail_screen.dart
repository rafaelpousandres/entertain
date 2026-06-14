import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../ui/app_form_field.dart';
import '../../../ui/edit_scaffold.dart';
import '../../../ui/primary_button.dart';
import '../../../ui/section_header.dart';
import '../../../ui/segmented_choice.dart';
import '../../../ui/stepper_field.dart';
import '../../catalog/data/dish_category.dart';
import '../../photos/data/media.dart';
import '../../photos/data/media_providers.dart';
import '../../photos/data/photo_storage.dart';
import '../../photos/widgets/photo_carousel_section.dart';
import '../../photos/widgets/photo_image.dart';
import '../../shopping/screens/event_shopping_panel.dart';
import '../data/event.dart';
import '../data/event_dish.dart';
import '../data/event_draft.dart';
import '../data/event_tab_store.dart';
import '../data/event_status.dart';
import '../data/events_providers.dart';
import '../widgets/event_formatters.dart';

/// Event detail screen (Spec 007 §2.1).
///
/// A three-tab layout replaces the previous header + segmented control:
///
///   * **Esdeveniment** — the event's own fields, editable in place, with a
///     "Desa" action shown only when there are unsaved changes (no separate
///     edit screen, no edit-pencil).
///   * **Menú** — the dish menu (unchanged).
///   * **Compra** — the shopping panel (unchanged in this phase).
///
/// The default tab is Menú, the most common landing point for ongoing
/// planning. The event title sits in the app bar so it stays in view across
/// tabs; delete lives in the app bar overflow menu.
class EventDetailScreen extends ConsumerStatefulWidget {
  const EventDetailScreen({
    super.key,
    required this.eventId,
    this.focusEventTab = false,
  });

  final String eventId;

  /// When true the screen opens on the **Esdeveniment** tab instead of the
  /// default Menú — used right after a duplication (Spec 009 §2.1) so the user
  /// lands on the name and date fields to complete the copy's essentials.
  final bool focusEventTab;

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen>
    with SingleTickerProviderStateMixin {
  // Spec 011 §2.7: built only once the remembered tab is known, so the screen
  // never renders on the default tab first and then jumps (no flicker).
  TabController? _tab;

  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  late EventDraft _draft;
  bool _seeded = false;
  bool _saving = false;
  bool _deleting = false;
  bool _duplicating = false;
  String? _titleError;

  @override
  void initState() {
    super.initState();
    _draft = EventDraft.empty();
    // §2.7: after a duplication we always land on the Esdeveniment tab to fill in
    // the copy's essentials, so skip the remembered tab. Otherwise read the
    // per-event remembered tab (default Menu) before building the controller, so
    // the screen renders directly on the right tab with no flicker.
    if (widget.focusEventTab) {
      _initTabController(0);
    } else {
      EventTabStore.readTabIndex(widget.eventId).then((index) {
        if (mounted) _initTabController(index);
      });
    }
  }

  void _initTabController(int initialIndex) {
    setState(() {
      _tab = TabController(length: 3, vsync: this, initialIndex: initialIndex)
        ..addListener(_onTabChanged);
    });
  }

  /// Rebuilds for the per-tab AppBar/bottom-bar actions and, once a switch has
  /// settled, persists the new tab as this event's last active tab (§2.7).
  void _onTabChanged() {
    final tab = _tab!;
    if (!tab.indexIsChanging) {
      EventTabStore.writeTabIndex(widget.eventId, tab.index);
    }
    setState(() {});
  }

  @override
  void dispose() {
    _tab?.dispose();
    _titleController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _seed(Event event) {
    if (_seeded) return;
    _draft = EventDraft.fromEvent(event);
    _titleController.text = _draft.title;
    _locationController.text = _draft.locationName ?? '';
    _notesController.text = _draft.notes ?? '';
    _seeded = true;
  }

  String _norm(String? value) => (value ?? '').trim();

  bool _sameDate(DateTime? a, DateTime? b) {
    if (a == null || b == null) return a == b;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _sameTime(TimeOfDay? a, TimeOfDay? b) {
    if (a == null || b == null) return a == b;
    return a.hour == b.hour && a.minute == b.minute;
  }

  /// Whether the in-place form diverges from the persisted event.
  bool _isDirty(Event e) {
    if (!_seeded) return false;
    return _titleController.text.trim() != e.title ||
        _draft.type != e.type ||
        _draft.format != e.format ||
        _draft.guestCount != e.guestCount ||
        !_sameDate(_draft.eventDate, e.eventDate) ||
        !_sameTime(_draft.eventTime, e.eventTime) ||
        _norm(_locationController.text) != _norm(e.locationName) ||
        _norm(_notesController.text) != _norm(e.notes);
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    _draft.title = _titleController.text;
    _draft.locationName = _locationController.text;
    _draft.notes = _notesController.text;
    if (_draft.title.trim().isEmpty) {
      setState(() => _titleError = l10n.fieldTitleRequired);
      return;
    }

    setState(() {
      _titleError = null;
      _saving = true;
    });
    try {
      await ref
          .read(eventsRepositoryProvider)
          .updateEvent(widget.eventId, _draft);
      ref.invalidate(eventsListProvider);
      ref.invalidate(eventByIdProvider(widget.eventId));
      // Spec 008 §2.4: a date change can flip the event to / from "past".
      ref.invalidate(eventReadinessProvider);
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.saveAction)));
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
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
      ),
    );
    if (confirmed != true) return;
    await _delete();
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _deleting = true);
    try {
      // Spec 010 §2.4: clear the event's media rows (the soft delete never
      // fires the cleanup trigger) and purge their blobs (non-fatal on
      // failure), then soft-delete the event.
      try {
        final paths = await ref
            .read(mediaRepositoryProvider)
            .deleteForEntity(MediaEntityType.event, widget.eventId);
        await ref
            .read(photoStorageProvider)
            .remove(MediaEntityType.event.bucket, paths);
      } catch (_) {}
      await ref.read(eventsRepositoryProvider).deleteEvent(widget.eventId);
      ref.invalidate(eventsListProvider);
      ref.invalidate(eventByIdProvider(widget.eventId));
      ref.invalidate(entityCoverPathsProvider(MediaEntityType.event));
      if (!mounted) return;
      context.go('/');
    } catch (_) {
      if (!mounted) return;
      setState(() => _deleting = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.deleteEventError)));
    }
  }

  Future<void> _confirmDuplicate(Event event) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          l10n.duplicateEventConfirmTitle,
          style: AppTypography.sectionTitle,
        ),
        content: Text(
          l10n.duplicateEventConfirmBody,
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
              l10n.duplicateEventAction,
              style: AppTypography.button.copyWith(
                color: AppColors.accentSecondary,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _duplicate(event);
  }

  Future<void> _duplicate(Event event) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _duplicating = true);
    try {
      final groupId = await ref.read(currentGroupIdProvider.future);
      final newId = await ref
          .read(eventsRepositoryProvider)
          .duplicateEvent(
            sourceEventId: widget.eventId,
            newTitle: l10n.duplicateEventNameTemplate(event.title),
            groupId: groupId,
          );
      ref.invalidate(eventsListProvider);
      ref.invalidate(eventReadinessProvider);
      if (!mounted) return;
      // Replace the source detail so the back gesture returns to the list, and
      // open on the Esdeveniment tab (§2.1) ready to fill in name and date.
      context.pushReplacement('/events/$newId?focus=event');
    } catch (_) {
      if (!mounted) return;
      setState(() => _duplicating = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.saveError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);

    // §2.7: until the remembered tab is read the controller does not exist yet;
    // show a brief loader (the event data is loading at the same moment anyway).
    final tab = _tab;
    if (tab == null) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }

    final eventAsync = ref.watch(eventByIdProvider(widget.eventId));
    final readinessAsync = ref.watch(eventReadinessProvider);

    // §2.3: guard the Esdeveniment tab form against losing unsaved edits.
    // `dirty` is derived from the live event so the guard and the AppBar save
    // action stay in sync even across tab switches.
    final event = eventAsync.value;
    final dirty = event != null && _isDirty(event);

    return PopScope(
      canPop: !dirty && !_deleting && !_duplicating,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _deleting || _duplicating) return;
        final navigator = Navigator.of(context);
        final discard = await showUnsavedChangesDialog(context);
        if (discard && navigator.mounted) navigator.pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: l10n.backAction,
            // maybePop runs the PopScope guard above instead of popping blindly.
            onPressed: _deleting || _duplicating
                ? null
                : () => Navigator.of(context).maybePop(),
          ),
          title: eventAsync.maybeWhen(
            data: (event) {
              final now = DateTime.now();
              final status = deriveEventStatus(
                event,
                readinessAsync.value?[event.id],
                DateTime(now.year, now.month, now.day),
              );
              return Row(
                children: [
                  Flexible(
                    child: Text(
                      event.title,
                      style: AppTypography.sectionTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _EventStatusChip(status: status),
                ],
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
          actions: [
            // §2.3: the Esdeveniment tab's save moves into the AppBar (always
            // visible above the keyboard), shown only when there are unsaved
            // edits. Other tabs keep their own bottom actions.
            if (tab.index == 0 && dirty)
              IconButton(
                icon: const Icon(Icons.check),
                color: AppColors.accentSecondary,
                tooltip: l10n.saveAction,
                onPressed: _saving ? null : _save,
              ),
            eventAsync.maybeWhen(
              data: (event) => PopupMenuButton<_OverflowAction>(
                icon: const Icon(Icons.more_vert),
                tooltip: l10n.moreActionsLabel,
                color: AppColors.surface,
                enabled: !_duplicating && !_deleting,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (action) {
                  switch (action) {
                    case _OverflowAction.duplicate:
                      _confirmDuplicate(event);
                    case _OverflowAction.delete:
                      _confirmDelete();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _OverflowAction.duplicate,
                    child: Text(
                      l10n.duplicateEventAction,
                      style: AppTypography.body,
                    ),
                  ),
                  PopupMenuItem(
                    value: _OverflowAction.delete,
                    child: Text(
                      l10n.deleteAction,
                      style: AppTypography.body.copyWith(
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                ],
              ),
              orElse: () => const SizedBox(width: 48),
            ),
          ],
          bottom: TabBar(
            controller: tab,
            labelColor: AppColors.accentSecondary,
            unselectedLabelColor: AppColors.textTertiary,
            indicatorColor: AppColors.accentSecondary,
            labelStyle: AppTypography.label,
            unselectedLabelStyle: AppTypography.label,
            tabs: [
              Tab(text: l10n.eventTabEvent),
              Tab(text: l10n.eventTabMenu),
              Tab(text: l10n.eventTabShopping),
            ],
          ),
        ),
        body: SafeArea(
          top: false,
          child: eventAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            ),
            error: (_, _) => _LoadError(
              message: l10n.eventsLoadError,
              onRetry: () => ref.invalidate(eventByIdProvider(widget.eventId)),
            ),
            data: (event) {
              _seed(event);
              return TabBarView(
                controller: tab,
                children: [
                  _buildEventTab(event, locale),
                  _MenuView(event: event),
                  EventShoppingPanel(eventId: event.id),
                ],
              );
            },
          ),
        ),
        bottomNavigationBar: eventAsync.maybeWhen(
          data: (event) {
            _seed(event);
            return _buildBottomBar(event, l10n);
          },
          orElse: () => null,
        ),
      ),
    );
  }

  Widget? _buildBottomBar(Event event, AppLocalizations l10n) {
    // §2.3: the Esdeveniment save now lives in the AppBar (always visible above
    // the keyboard); Menú keeps its "Afegeix plat" action; Compra has none (the
    // panel owns its per-section actions).
    if (_tab!.index == 1) {
      return _ActionBar(
        child: PrimaryButton(
          label: l10n.addDishToMenuAction,
          icon: Icons.add,
          onPressed: () => context.push('/events/${event.id}/add-dish'),
        ),
      );
    }
    return null;
  }

  Widget _buildEventTab(Event event, Locale locale) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        // Spec 010 §2.3: the photo carousel sits at the top of the editor,
        // above the title field, with the standard body padding above it
        // (moved here from between Lloc and Notes). Same reusable widget the
        // dish and ingredient editors use.
        PhotoCarouselSection(type: MediaEntityType.event, entityId: event.id),
        const SizedBox(height: 20),
        FieldLabel(
          label: l10n.fieldTitleLabel,
          child: AppTextField(
            controller: _titleController,
            hintText: l10n.fieldTitleHint,
            onChanged: (_) => setState(() {
              if (_titleError != null &&
                  _titleController.text.trim().isNotEmpty) {
                _titleError = null;
              }
            }),
          ),
        ),
        if (_titleError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _titleError!,
              style: AppTypography.caption.copyWith(color: AppColors.danger),
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
            onChanged: (_) => setState(() {}),
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
            onChanged: (_) => setState(() {}),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _draft.eventDate ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
      builder: _pickerTheme,
    );
    if (picked != null) setState(() => _draft.eventDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _draft.eventTime ?? const TimeOfDay(hour: 14, minute: 0),
      builder: _pickerTheme,
    );
    if (picked != null) setState(() => _draft.eventTime = picked);
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

  String _formatTime(TimeOfDay value, Locale locale) {
    final dt = DateTime(2000, 1, 1, value.hour, value.minute);
    return DateFormat.Hm(locale.toLanguageTag()).format(dt);
  }
}

enum _OverflowAction { duplicate, delete }

/// Small status pill for the detail header (Spec 008 §2.4): a coloured dot and
/// the textual status label.
class _EventStatusChip extends StatelessWidget {
  const _EventStatusChip({required this.status});

  final DerivedEventStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = derivedEventStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            derivedEventStatusLabel(l10n, status),
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: const BoxDecoration(
          color: AppColors.bg,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: child,
      ),
    );
  }
}

class _MenuView extends ConsumerWidget {
  const _MenuView({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final dishesAsync = ref.watch(eventDishesProvider(event.id));

    // §2: photos for menu rows mirror the catalog. A menu dish is a snapshot,
    // so its photo is the cover (first by position) of the catalog dish it came
    // from (source_dish_id). Spec 010 §2.4: the cover comes from the polymorphic
    // media table via [entityCoverPathsProvider]; thumbnails fill in once it
    // loads and rows render without them in the meantime.
    final catalogPhotos =
        ref.watch(entityCoverPathsProvider(MediaEntityType.dish)).value ??
        const <String, String>{};

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        dishesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            ),
          ),
          error: (_, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              l10n.eventsLoadError,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          data: (dishes) => dishes.isEmpty
              ? const _MenuEmpty()
              : _MenuByCategory(
                  dishes: dishes,
                  eventId: event.id,
                  catalogPhotos: catalogPhotos,
                ),
        ),
      ],
    );
  }
}

class _MenuEmpty extends StatelessWidget {
  const _MenuEmpty();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        l10n.menuEmptyBody,
        textAlign: TextAlign.center,
        style: AppTypography.body.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

class _MenuByCategory extends StatefulWidget {
  const _MenuByCategory({
    required this.dishes,
    required this.eventId,
    required this.catalogPhotos,
  });

  final List<EventDish> dishes;
  final String eventId;

  /// §2: catalog dish id → photo_path (null when none), for the menu thumbnails.
  final Map<String, String?> catalogPhotos;

  @override
  State<_MenuByCategory> createState() => _MenuByCategoryState();
}

class _MenuByCategoryState extends State<_MenuByCategory> {
  late final Map<DishCategory, bool> _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = {for (final c in DishCategory.values) c: true};
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final byCategory = <DishCategory, List<EventDish>>{};
    for (final dish in widget.dishes) {
      byCategory.putIfAbsent(dish.category, () => []).add(dish);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final category in dishCategoryOrder)
          if (byCategory[category] != null) ...[
            SectionHeader(
              icon: dishCategoryIcon(category),
              label: dishCategoryLabel(l10n, category),
              count: byCategory[category]!.length,
              expanded: _expanded[category]!,
              onToggle: () =>
                  setState(() => _expanded[category] = !_expanded[category]!),
            ),
            if (_expanded[category]!)
              Column(
                children: [
                  for (final dish in byCategory[category]!)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _DishRow(
                        dish: dish,
                        photoPath: dish.sourceDishId == null
                            ? null
                            : widget.catalogPhotos[dish.sourceDishId],
                        onTap: () => context.push(
                          '/events/${widget.eventId}/dishes/${dish.id}',
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                ],
              ),
          ],
      ],
    );
  }
}

class _DishRow extends StatelessWidget {
  const _DishRow({
    required this.dish,
    required this.photoPath,
    required this.onTap,
  });

  final EventDish dish;

  /// §2: the source catalog dish's photo_path, or null when it has none (or
  /// the catalog dish is gone). Null shows no thumbnail, matching the catalog.
  final String? photoPath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              // §2: inline photo thumbnail when the catalog dish has one,
              // consistent with the Dishes catalog rows.
              if (photoPath != null) ...[
                RowPhotoThumb(
                  photoRef: (bucket: PhotoStorage.dishBucket, path: photoPath!),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      dish.name,
                      style: AppTypography.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.eventDishServings(dish.servings),
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                color: AppColors.disabled,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onRetry,
              child: Text(
                l10n.retryAction,
                style: AppTypography.button.copyWith(color: AppColors.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
