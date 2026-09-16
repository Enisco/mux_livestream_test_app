/// What the reader has given, and the paperwork that came back.
///
/// Every amount is a preformatted string: the currency, its grouping and the
/// converted figure all come from the ministry's own settings, so the screen
/// prints what it is handed rather than formatting anything itself.
library;

/// The document a gift produced. Each opens a different thing, and the design
/// names them differently, so the kind is carried rather than inferred.
enum GiftDocument {
  receipt('Receipt'),
  invoice('Invoice'),
  voucher('Voucher');

  const GiftDocument(this.label);

  final String label;
}

class Gift {
  const Gift({
    required this.id,
    required this.ministry,
    required this.fund,
    required this.date,
    required this.amount,
    required this.document,
    this.ministryVerified = false,
    this.converted = '',
  });

  final String id;
  final String ministry;
  final bool ministryVerified;

  /// "General Fund", "Special Projects" — what it was given towards.
  final String fund;

  /// "Jun 6".
  final String date;

  /// "₦225,000.00", in the ministry's currency.
  final String amount;

  /// "$145.00" — the same gift in the reader's own, when they differ.
  final String converted;

  final GiftDocument document;
}

/// A month's gifts under the heading the design gives it.
class GivingMonth {
  const GivingMonth({required this.label, required this.gifts});

  /// "JUNE 2026".
  final String label;

  final List<Gift> gifts;
}

/// The card across the top: one year's giving at a glance.
class GivingSummary {
  const GivingSummary({
    required this.year,
    required this.total,
    required this.gifts,
    required this.ministries,
    this.converted = '',
  });

  final int year;
  final String total;

  /// "$145.00 total". Empty when there is nothing to convert.
  final String converted;

  final int gifts;
  final int ministries;

  bool get isEmpty => gifts == 0;
}
