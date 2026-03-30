import 'package:flutter_test/flutter_test.dart';
import 'package:notes_app/models/user_subscription.dart';

void main() {
  group('UserSubscription.fromJson', () {
    test('parses a standard active subscription payload', () {
      final subscription = UserSubscription.fromJson({
        'planCode': 'monthly',
        'planId': 'plan_SWFxzT9zN5wECO',
        'subscriptionId': 'sub_SX573ETIpr1zvh',
        'status': 'active',
        'currentEnd': '2026-04-28T18:30:00.000Z',
        'remainingCount': 347,
        'totalCount': 348,
      });

      expect(subscription.status, 'active');
      expect(subscription.planCode, 'monthly');
      expect(subscription.subscriptionId, 'sub_SX573ETIpr1zvh');
      expect(subscription.currentEnd, DateTime.parse('2026-04-28T18:30:00.000Z'));
      expect(subscription.isEntitled, isTrue);
    });

    test('recovers populated values from the malformed backend shape', () {
      final subscription = UserSubscription.fromJson({
        'planCode': null,
        'planId': null,
        'subscriptionId': null,
        'status': 'none',
        'paidCount': 1,
        'remainingCount': null,
        'totalCount': null,
        'notes': {
          'app_name': 'College Notes',
          'app_plan_code': 'monthly',
        },
        r'$__parent': {
          'subscription': {
            'planCode': 'monthly',
            'planId': 'plan_SWFxzT9zN5wECO',
            'subscriptionId': 'sub_SX573ETIpr1zvh',
            'status': 'active',
            'currentEnd': '2026-04-28T18:30:00.000Z',
            'remainingCount': 347,
            'totalCount': 348,
          },
        },
        '_doc': {
          'planCode': 'monthly',
          'planId': 'plan_SWFxzT9zN5wECO',
          'subscriptionId': 'sub_SX573ETIpr1zvh',
          'status': 'active',
          'currentEnd': '2026-04-28T18:30:00.000Z',
          'remainingCount': 347,
          'totalCount': 348,
          'lastSignatureVerifiedAt': '2026-03-29T14:56:06.923Z',
        },
      });

      expect(subscription.status, 'active');
      expect(subscription.planCode, 'monthly');
      expect(subscription.subscriptionId, 'sub_SX573ETIpr1zvh');
      expect(subscription.remainingCount, 347);
      expect(subscription.totalCount, 348);
      expect(
        subscription.lastSignatureVerifiedAt,
        DateTime.parse('2026-03-29T14:56:06.923Z'),
      );
      expect(subscription.isEntitled, isTrue);
    });

    test('parses Mongo extended JSON dates', () {
      final subscription = UserSubscription.fromJson({
        'status': 'active',
        'currentEnd': {r'$date': '2026-04-28T18:30:00.000Z'},
      });

      expect(subscription.currentEnd, DateTime.parse('2026-04-28T18:30:00.000Z'));
    });
  });
}
