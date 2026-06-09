import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../ui/primary_button.dart';
import '../../../ui/section_header.dart';
import '../data/event.dart';
import '../data/event_status.dart';
import '../data/events_providers.dart';
import '../widgets/event_card.dart';
import '../widgets/event_formatters.dart';

/// App home (spec 003 §2.2). Lists the user's active events in the agreed
/// order (upcoming first, past after, dateless at the end) and exposes a
/// single primary action — "New event" — in the bottom action bar.
class EventsListScreen extends ConsumerWidget {
  const EventsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final eventsAsync = ref.watch(eventsListProvider);
    final readinessAsync = ref.watch(eventReadinessProvider);
    final photosAsync = ref.watch(eventFirstPhotosProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(l10n.eventsScreenTitle, style: AppTypography.display),
      ),
      body: SafeArea(
        top: false,
        child: eventsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          ),
          error: (_, _) => _LoadError(
            message: l10n.eventsLoadError,
            onRetry: () => ref.invalidate(eventsListProvider),
          ),
          data: (events) => events.isEmpty
              ? const _EmptyState()
              : _GroupedEventList(
                  events: events,
                  readiness: readinessAsync.value ?? const {},
                  firstPhotos: photosAsync.value ?? const {},
                ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: const BoxDecoration(
          color: AppColors.bg,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: PrimaryButton(
          label: l10n.newEventAction,
          icon: Icons.add,
          onPressed: () => context.push('/events/new'),
        ),
      ),
    );
  }
}

/// The events list grouped by derived status into three collapsible sections
/// (Spec 008 §2.4): En preparació, Llest, Passat. In-preparation and ready are
/// expanded by default, past collapsed; empty sections are omitted. Collapse
/// state is per-session (not persisted).
class _GroupedEventList extends StatefulWidget {
  const _GroupedEventList({
    required this.events,
    required this.readiness,
    required this.firstPhotos,
  });

  final List<Event> events;
  final Map<String, EventReadiness> readiness;

  /// Event id → first album photo path (Spec 009 §6.2), for the card thumbnail.
  final Map<String, String> firstPhotos;

  @override
  State<_GroupedEventList> createState() => _GroupedEventListState();
}

class _GroupedEventListState extends State<_GroupedEventList> {
  final _expanded = <DerivedEventStatus, bool>{
    DerivedEventStatus.inPreparation: true,
    DerivedEventStatus.ready: true,
    DerivedEventStatus.past: false,
  };

  // Section render order (Spec §2.4).
  static const _order = [
    DerivedEventStatus.inPreparation,
    DerivedEventStatus.ready,
    DerivedEventStatus.past,
  ];

  IconData _icon(DerivedEventStatus status) => switch (status) {
    DerivedEventStatus.inPreparation => Icons.hourglass_empty,
    DerivedEventStatus.ready => Icons.check_circle_outline,
    DerivedEventStatus.past => Icons.history,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final byStatus = <DerivedEventStatus, List<Event>>{
      for (final s in _order) s: [],
    };
    for (final event in widget.events) {
      final status = deriveEventStatus(event, widget.readiness[event.id], today);
      byStatus[status]!.add(event);
    }
    // Within each section, dateless events sink last (by created_at desc).
    // Past is sorted date *descending* (most recent past first, closest to
    // today at the top); in-preparation and ready ascending (soonest first).
    for (final entry in byStatus.entries) {
      final descending = entry.key == DerivedEventStatus.past;
      entry.value.sort((a, b) => _byDate(a, b, descending: descending));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      children: [
        for (final status in _order)
          if (byStatus[status]!.isNotEmpty) ...[
            SectionHeader(
              icon: _icon(status),
              label: derivedEventStatusLabel(l10n, status),
              count: byStatus[status]!.length,
              expanded: _expanded[status]!,
              onToggle: () =>
                  setState(() => _expanded[status] = !_expanded[status]!),
            ),
            if (_expanded[status]!)
              for (final event in byStatus[status]!)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: EventCard(
                    event: event,
                    status: status,
                    photoPath: widget.firstPhotos[event.id],
                    onTap: () =>
                        GoRouter.of(context).push('/events/${event.id}'),
                  ),
                ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  int _byDate(Event a, Event b, {required bool descending}) {
    final aDate = a.eventDate;
    final bDate = b.eventDate;
    // Dateless events always sink to the bottom, newest-created first,
    // regardless of the section's direction.
    if (aDate == null && bDate == null) {
      return b.createdAt.compareTo(a.createdAt);
    }
    if (aDate == null) return 1;
    if (bDate == null) return -1;
    return descending ? bDate.compareTo(aDate) : aDate.compareTo(bDate);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.accentSecondarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.event_outlined,
                color: AppColors.accentSecondary,
                size: 26,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.eventsEmptyTitle,
              style: AppTypography.sectionTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.eventsEmptyBody,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
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
