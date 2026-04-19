import 'package:equatable/equatable.dart';

class Region extends Equatable {
  const Region({
    required this.country,
    required this.city,
    required this.district,
  });

  final String country;
  final String city;
  final String district;

  String get key => '${city}_$district';
  String get topicFull => 'tr_${city}_$district';
  String get topicCity => 'tr_$city';
  String get topicCountry => 'tr';

  Map<String, dynamic> toMap() => {
        'country': country,
        'city': city,
        'district': district,
      };

  factory Region.fromMap(Map<String, dynamic> map) => Region(
        country: map['country'] as String? ?? 'TR',
        city: map['city'] as String? ?? '',
        district: map['district'] as String? ?? '',
      );

  @override
  List<Object?> get props => [country, city, district];
}
