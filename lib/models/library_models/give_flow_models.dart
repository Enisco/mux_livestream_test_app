/// Offering a gift, as the giver sees it.
library;

/// One purpose a gift can be directed at.
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
