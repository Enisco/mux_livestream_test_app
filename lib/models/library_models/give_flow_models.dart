/// Offering a gift, as the giver sees it.
///
/// The donor's share of Giving is deliberately thin. Flutter asks whether a
/// ministry can be given to, which purpose the gift is for, and then hands the
/// rest — amount, currency, fee breakdown, card details — to the first-party
/// web surface in a system browser. Nothing here touches money.
library;

/// One purpose a gift can be directed at.
///
/// The reserved `general` fund always exists and cannot be deactivated, so a
/// ministry's list is never empty. Slugs are immutable even when a fund is
/// renamed, which is what makes a shared `?give=` link keep working — so the
/// slug is what travels, never the name.
class GivingFundOption {
  const GivingFundOption({
    required this.id,
    required this.slug,
    required this.name,
    this.description,
  });

  /// The reserved purpose every ministry has.
  static const generalSlug = 'general';

  final String id;
  final String slug;
  final String name;
  final String? description;

  bool get isGeneral => slug == generalSlug;

  factory GivingFundOption.fromJson(Map<String, dynamic> json) =>
      GivingFundOption(
        id: json['id'] as String? ?? '',
        slug: json['slug'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String?,
      );
}
