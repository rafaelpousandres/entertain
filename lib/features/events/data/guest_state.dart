/// Spec 023 §1.3 — a guest's RSVP state, set manually by the host (Layer 1).
///
/// Mirrors the shape of [DishCategory] in the catalog: an enum, a wire mapping
/// to/from the Postgres `event_guests.state` text + check constraint, a render
/// order for the accordion, and label/icon helpers. Layer 2 (RSVP link) will
/// flip these from guest responses; Layer 1 keeps them host-driven.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';

enum GuestState { pendent, confirmat, excusat }

extension GuestStateWire on GuestState {
  String get wire => switch (this) {
    GuestState.pendent => 'pendent',
    GuestState.confirmat => 'confirmat',
    GuestState.excusat => 'excusat',
  };

  static GuestState parse(String? value) => switch (value) {
    'confirmat' => GuestState.confirmat,
    'excusat' => GuestState.excusat,
    _ => GuestState.pendent,
  };
}

/// Accordion render order (§1.4): pending first (needs attention), then the
/// resolved states.
const List<GuestState> guestStateOrder = [
  GuestState.pendent,
  GuestState.confirmat,
  GuestState.excusat,
];

String guestStateLabel(AppLocalizations l10n, GuestState state) => switch (state) {
  GuestState.pendent => l10n.guestStatePending,
  GuestState.confirmat => l10n.guestStateConfirmed,
  GuestState.excusat => l10n.guestStateExcused,
};

IconData guestStateIcon(GuestState state) => switch (state) {
  GuestState.pendent => Icons.schedule_outlined,
  GuestState.confirmat => Icons.check_circle_outline,
  GuestState.excusat => Icons.cancel_outlined,
};

/// Accent for the state's section header badge (design system colours).
Color guestStateColor(GuestState state) => switch (state) {
  GuestState.pendent => AppColors.textTertiary,
  GuestState.confirmat => AppColors.accentSecondary,
  GuestState.excusat => AppColors.danger,
};
