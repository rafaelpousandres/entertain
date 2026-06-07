import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../data/event.dart';
import '../data/event_status.dart';
import 'event_formatters.dart';

/// Single row in the events list. Card per design system §5 (surface, 1 px
/// border, radius 14, padding 11–13), with a date leading element, primary
/// + secondary text and a trailing chevron. A coloured dot next to the title
/// shows the derived status (Spec 008 §2.4).
class EventCard extends StatelessWidget {
  const EventCard({
    super.key,
    required this.event,
    required this.status,
    required this.onTap,
  });

  final Event event;
  final DerivedEventStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);

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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _DateBadge(date: event.eventDate, locale: locale, l10n: l10n),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: derivedEventStatusColor(status),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            event.title,
                            style: AppTypography.sectionTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      eventListMetadata(l10n, event, locale),
                      style: AppTypography.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

/// Date leading element. Renders day + abbreviated month when the event
/// has a date; falls back to a neutral "no date" pill otherwise.
class _DateBadge extends StatelessWidget {
  const _DateBadge({
    required this.date,
    required this.locale,
    required this.l10n,
  });

  final DateTime? date;
  final Locale locale;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    if (date == null) {
      return Container(
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          l10n.noDateLabel,
          textAlign: TextAlign.center,
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
          maxLines: 2,
        ),
      );
    }

    final day = DateFormat.d(locale.toLanguageTag()).format(date!);
    final month = DateFormat.MMM(locale.toLanguageTag()).format(date!);

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.accentSecondarySoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            day,
            style: AppTypography.sectionTitle.copyWith(
              color: AppColors.accentSecondary,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            month.toLowerCase(),
            style: AppTypography.caption.copyWith(
              color: AppColors.accentSecondary,
              fontSize: 11,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
