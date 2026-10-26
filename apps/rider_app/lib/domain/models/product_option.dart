
/// A selectable ride product (tier) shown on the fare-review screen.
///
/// The [multiplier] scales the authoritative server [Quote] estimate purely
/// for display, mirroring how Uber lists UberX / Comfort / XL side by side.
/// The amount actually charged is always recomputed by the server at ride
/// completion, so nothing here is a pricing source of truth.
class ProductOption {
  const ProductOption({
    required this.id,
    required this.name,
    required this.description,
    required this.seats,
    required this.multiplier,
    required this.etaMinutes,
  });

  final String id;
  final String name;
  final String description;
  final int seats;

  /// Relative factor applied to the server estimate to show this tier's price.
  final double multiplier;

  /// Minutes until a driver of this tier is expected to arrive.
  final int etaMinutes;

  /// This tier's estimated amount for a trip whose server quote is [baseAmount].
  int pricedFrom(String baseAmount) =>
      ((double.tryParse(baseAmount) ?? 0) * multiplier).round();

  @override
  bool operator ==(Object other) =>
      other is ProductOption &&
      other.id == id &&
      other.name == name &&
      other.description == description &&
      other.seats == seats &&
      other.multiplier == multiplier &&
      other.etaMinutes == etaMinutes;

  @override
  int get hashCode =>
      Object.hash(id, name, description, seats, multiplier, etaMinutes);
}
