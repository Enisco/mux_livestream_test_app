import 'package:test_app/models/library_models/giving_models.dart';

/// Placeholder giving records.
///
/// TEMPORARY. `POST /v1/payments/...` takes a gift, but the staging spec has
/// no route that reads a reader's giving back — no list, no yearly totals, and
/// no statement or receipt document. Every figure and every document link here
/// is invented.
///
/// To retire this: delete the file and fix the import errors in
/// `giving_screen.dart`.
abstract final class GivingDummyData {
  static const years = <int>[2026, 2025, 2024];

  /// The headline card, keyed by the year the picker is on.
  static const summaries = <int, GivingSummary>{
    2026: GivingSummary(
      year: 2026,
      total: '₦225,000.00',
      converted: '\$145.00',
      gifts: 6,
      ministries: 3,
    ),
    2025: GivingSummary(
      year: 2025,
      total: '₦1,855,000.00',
      converted: '\$1,205.00',
      gifts: 14,
      ministries: 5,
    ),
    // The design's empty state is a year with nothing in it.
    2024: GivingSummary(
      year: 2024,
      total: '₦0.00',
      converted: '',
      gifts: 0,
      ministries: 0,
    ),
  };

  static const _june2026 = <Gift>[
    Gift(
      id: 'g1',
      ministry: 'Cynthia Morgan',
      ministryVerified: true,
      fund: 'General Fund',
      date: 'Jun 6',
      amount: '₦225,000.00',
      converted: '\$145.00',
      document: GiftDocument.receipt,
    ),
    Gift(
      id: 'g2',
      ministry: 'Marcus Lee',
      ministryVerified: true,
      fund: 'Special Projects',
      date: 'Jun 7',
      amount: '₦150,000.00',
      converted: '\$200.00',
      document: GiftDocument.invoice,
    ),
    Gift(
      id: 'g3',
      ministry: 'Aisha Patel',
      ministryVerified: true,
      fund: 'Marketing Budget',
      date: 'Jun 8',
      amount: '₦300,000.00',
      converted: '\$180.00',
      document: GiftDocument.receipt,
    ),
    Gift(
      id: 'g4',
      ministry: 'Julian Torres',
      ministryVerified: true,
      fund: 'R&D Fund',
      date: 'Jun 9',
      amount: '₦275,000.00',
      converted: '\$210.00',
      document: GiftDocument.voucher,
    ),
    Gift(
      id: 'g5',
      ministry: 'Nina Gomez',
      ministryVerified: true,
      fund: 'Community Outreach',
      date: 'Jun 10',
      amount: '₦125,000.00',
      converted: '\$130.00',
      document: GiftDocument.receipt,
    ),
    Gift(
      id: 'g6',
      ministry: 'Raj Singh',
      ministryVerified: true,
      fund: 'Operations',
      date: 'Jun 11',
      amount: '₦400,000.00',
      converted: '\$190.00',
      document: GiftDocument.invoice,
    ),
    Gift(
      id: 'g7',
      ministry: 'Elena Kim',
      ministryVerified: true,
      fund: 'Training Fund',
      date: 'Jun 12',
      amount: '₦180,000.00',
      converted: '\$175.00',
      document: GiftDocument.voucher,
    ),
  ];

  /// Gifts grouped under the month they were given, newest month first.
  static const months = <int, List<GivingMonth>>{
    2026: [
      GivingMonth(label: 'JUNE 2026', gifts: _june2026),
      GivingMonth(label: 'MAY 2026', gifts: _june2026),
    ],
    2025: [GivingMonth(label: 'JUNE 2025', gifts: _june2026)],
    2024: [],
  };
}
