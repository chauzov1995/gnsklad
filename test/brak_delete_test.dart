import 'package:flutter_test/flutter_test.dart';
import 'package:gnsklad/brak_delete.dart';

void main() {
  test('only one unprocessed log and one defect permit deletion', () {
    expect(brakDeletionBlockedReason({
      'LOG_COUNT': 1, 'UNCHECKED_COUNT': 1, 'BRAK_COUNT': 1,
    }), isNull);
  });

  test('missing, checked, duplicate and incomplete matches are blocked', () {
    for (final row in <Map<String, int>>[
      {'LOG_COUNT': 0, 'UNCHECKED_COUNT': 0, 'BRAK_COUNT': 1},
      {'LOG_COUNT': 1, 'UNCHECKED_COUNT': 0, 'BRAK_COUNT': 1},
      // One checked plus one unchecked log is still ambiguous.
      {'LOG_COUNT': 2, 'UNCHECKED_COUNT': 1, 'BRAK_COUNT': 1},
      {'LOG_COUNT': 1, 'UNCHECKED_COUNT': 1, 'BRAK_COUNT': 2},
      {},
    ]) {
      expect(brakDeletionBlockedReason(row), isNotNull);
    }
  });
}
