import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

/// Автор. Содержит вложенные модели [Address] (с вложенным [Geo]) и [Company].
/// Всё, кроме id/name/username/email, необязательно — приложение не падает,
/// если сервер не прислал эти поля.
@JsonSerializable(explicitToJson: true)
class User {
  const User({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    this.phone,
    this.website,
    this.address,
    this.company,
  });

  final int id;
  final String name;
  final String username;
  final String email;
  final String? phone;
  final String? website;
  final Address? address;
  final Company? company;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  Map<String, dynamic> toJson() => _$UserToJson(this);
}

@JsonSerializable(explicitToJson: true)
class Address {
  const Address({this.street, this.suite, this.city, this.zipcode, this.geo});

  final String? street;
  final String? suite;
  final String? city;
  final String? zipcode;
  final Geo? geo;

  factory Address.fromJson(Map<String, dynamic> json) =>
      _$AddressFromJson(json);

  Map<String, dynamic> toJson() => _$AddressToJson(this);
}

@JsonSerializable()
class Geo {
  const Geo({this.lat, this.lng});

  final String? lat;
  final String? lng;

  factory Geo.fromJson(Map<String, dynamic> json) => _$GeoFromJson(json);

  Map<String, dynamic> toJson() => _$GeoToJson(this);
}

@JsonSerializable()
class Company {
  const Company({this.name, this.catchPhrase, this.bs});

  final String? name;
  final String? catchPhrase;
  final String? bs;

  factory Company.fromJson(Map<String, dynamic> json) =>
      _$CompanyFromJson(json);

  Map<String, dynamic> toJson() => _$CompanyToJson(this);
}
