import 'package:entertain/features/shopping/data/message_composer.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests the supplier message body composer after Fixes §2.5: no event title
/// or date leak into the message; the optional leading line carries only the
/// needed-by sentence, and is omitted entirely when empty.
void main() {
  group('composeMessageBody', () {
    const items = ['500 g gambes', '2 unit llimones'];

    test('with a leading line, it heads the body then a blank line', () {
      final body = composeMessageBody(
        leadingLine: 'Per al dia 5 de juny',
        itemLines: items,
        signature: 'Rafael',
      );
      expect(body, 'Per al dia 5 de juny\n\n500 g gambes\n2 unit llimones\n\nRafael');
    });

    test('an empty leading line is omitted with no dangling blank', () {
      final body = composeMessageBody(
        leadingLine: '',
        itemLines: items,
        signature: 'Rafael',
      );
      expect(body, '500 g gambes\n2 unit llimones\n\nRafael');
    });

    test('a blank-only leading line is treated as empty', () {
      final body = composeMessageBody(
        leadingLine: '   ',
        itemLines: items,
        signature: '',
      );
      expect(body, '500 g gambes\n2 unit llimones');
    });

    test('an empty signature is omitted', () {
      final body = composeMessageBody(
        leadingLine: 'Per al dia 5 de juny',
        itemLines: items,
        signature: '',
      );
      expect(body, 'Per al dia 5 de juny\n\n500 g gambes\n2 unit llimones');
    });
  });
}
