import 'package:supabase_flutter/supabase_flutter.dart';

import '../../ai_dish_assistant/data/dish_assistant_repository.dart'
    show DishAssistantRepository, QuotaExceededException;
import '../../events/data/events_repository.dart';
import '../../stock_photos/data/quota.dart' show QuotaStatus, currentPeriodUtc;
import 'menu_proposal.dart';
import 'menu_wizard.dart';

/// Spec 022 §4/§5 — client side of the `menu-wizard` flow.
///
/// `propose` (charges quota) is the only Edge action; the Anthropic + Pexels
/// keys live only in the function. "Accept" is composed here from already-tested
/// pieces — the deployed `dish-assistant` `save` (per new dish) and the existing
/// [EventsRepository.addDishToEvent] / [EventsRepository.addDrinkToEvent] (per
/// item) — so the menu-snapshot + servings-scaling logic is never duplicated.
class MenuWizardRepository {
  MenuWizardRepository(this._client, this._dishAssistant, this._events);

  final SupabaseClient _client;
  final DishAssistantRepository _dishAssistant;
  final EventsRepository _events;

  /// §4 propose — CHARGES QUOTA. Event params + the question answers + locale ->
  /// Claude proposes a menu (catalog dish/drink refs + new dish cards). In
  /// "completa" mode (the menu already has items) the proposal is complementary.
  /// Returns the items for review + updated usage; throws
  /// [QuotaExceededException] on 402. Nothing is persisted yet — see [accept].
  Future<({MenuProposal proposal, QuotaStatus usage})> propose({
    required String eventId,
    required Map<String, dynamic> answers,
    required String freeText,
    required String locale,
  }) async {
    try {
      final res = await _client.functions.invoke(
        'menu-wizard',
        body: {
          'action': 'propose',
          'event_id': eventId,
          'answers': answers,
          'free_text': freeText,
          'locale': locale,
        },
      );
      final data = (res.data as Map).cast<String, dynamic>();
      final usage = (data['usage'] as Map).cast<String, dynamic>();
      return (
        proposal: MenuProposal.fromItems(
          (data['items'] as List?) ?? const [],
          locale: locale,
        ),
        usage: QuotaStatus(
          used: (usage['used'] as num).toInt(),
          limit: (usage['limit'] as num).toInt(),
        ),
      );
    } on FunctionException catch (e) {
      if (e.status == 402) {
        final details = e.details;
        final map = details is Map ? details.cast<String, dynamic>() : null;
        throw QuotaExceededException(
          used: (map?['used'] as num?)?.toInt() ?? 0,
          limit: (map?['limit'] as num?)?.toInt() ?? kMenuWizardDefaultLimit,
        );
      }
      rethrow;
    }
  }

  /// §4 accept — NO extra quota (already charged at propose). Persists the
  /// user's selected items: each new dish is created in the catalog first
  /// (reusing `dish-assistant` save), then every selected dish/drink is added to
  /// the event menu with the event's quantities. Best-effort per item — one
  /// failure doesn't abort the rest; returns how many were added and how many
  /// failed so the UI can report honestly.
  Future<({int added, int failed})> accept({
    required String eventId,
    required List<ProposedItem> items,
  }) async {
    var added = 0;
    var failed = 0;
    for (final item in items) {
      try {
        switch (item) {
          case NewDishItem(:final card):
            // Create the catalog dish (ingredients + i18n + photo), then add it
            // to this event's menu — the same two steps the manual flow uses.
            final dishId = await _dishAssistant.save(card: card);
            await _events.addDishToEvent(eventId: eventId, dishId: dishId);
          case CatalogDishItem(:final dishId):
            await _events.addDishToEvent(eventId: eventId, dishId: dishId);
          case CatalogDrinkItem(:final drinkId):
            await _events.addDrinkToEvent(eventId: eventId, drinkId: drinkId);
        }
        added++;
      } catch (_) {
        failed++;
      }
    }
    return (added: added, failed: failed);
  }

  /// Reads the group's usage for the current period + its effective limit
  /// (entitlement row, else the system default). Drives the "N de 2" header.
  Future<QuotaStatus> fetchQuota(String groupId) async {
    final period = currentPeriodUtc();
    final usageRow = await _client
        .from('quota_usage')
        .select('used')
        .eq('group_id', groupId)
        .eq('quota_key', kMenuWizardQuotaKey)
        .eq('period', period)
        .maybeSingle();
    final entRow = await _client
        .from('quota_entitlements')
        .select('monthly_limit')
        .eq('group_id', groupId)
        .eq('quota_key', kMenuWizardQuotaKey)
        .maybeSingle();
    return QuotaStatus(
      used: (usageRow?['used'] as num?)?.toInt() ?? 0,
      limit:
          (entRow?['monthly_limit'] as num?)?.toInt() ?? kMenuWizardDefaultLimit,
    );
  }
}
