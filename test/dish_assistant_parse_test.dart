import 'package:entertain/features/ai_dish_assistant/data/dish_suggestion.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spec 020 §8 (v3) — pure parse of a Phase 1 suggestion ({title, url}).
void main() {
  test('parses title and url', () {
    final s = DishSuggestion.fromJson(const {
      'title': 'Caldereta de llagosta',
      'url': 'https://example.test/caldereta',
    });
    expect(s.title, 'Caldereta de llagosta');
    expect(s.url, 'https://example.test/caldereta');
    expect(s.hasUrl, isTrue);
  });

  test('trims whitespace and tolerates missing fields', () {
    final s = DishSuggestion.fromJson(const {'title': '  Paella  '});
    expect(s.title, 'Paella');
    expect(s.url, '');
    expect(s.hasUrl, isFalse);
  });

  test('hasUrl is false for a non-http value', () {
    final s = DishSuggestion.fromJson(const {
      'title': 'X',
      'url': 'ftp://nope',
    });
    expect(s.hasUrl, isFalse);
  });
}
