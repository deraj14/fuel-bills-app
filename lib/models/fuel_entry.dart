class FuelEntry {
  final int? id;
  final DateTime date;
  final double odometer;
  final double? liters;
  final double? pricePerLiter;

  FuelEntry({
    this.id,
    required this.date,
    required this.odometer,
    this.liters,
    this.pricePerLiter,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'odometer': odometer,
      'liters': liters,
      'price_per_liter': pricePerLiter,
    };
  }

  factory FuelEntry.fromMap(Map<String, dynamic> map) {
    return FuelEntry(
      id: map['id'] as int?,
      date: DateTime.parse(map['date'] as String),
      odometer: (map['odometer'] as num).toDouble(),
      liters: map['liters'] == null ? null : (map['liters'] as num).toDouble(),
      pricePerLiter: map['price_per_liter'] == null
          ? null
          : (map['price_per_liter'] as num).toDouble(),
    );
  }
}
