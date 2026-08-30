import 'package:epistola/domain/models/substitution_call_receipt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('derives stable call id from revision', () {
    const receipt = SubstitutionCallReceipt(userId: 'user-1', revision: 7);

    expect(receipt.callId, '7');
  });

  test('different revisions produce different call ids', () {
    const first = SubstitutionCallReceipt(userId: 'user-1', revision: 7);

    const second = SubstitutionCallReceipt(userId: 'user-2', revision: 8);

    expect(first.callId, isNot(second.callId));
  });
}
