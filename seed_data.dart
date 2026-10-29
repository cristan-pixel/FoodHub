// lib/services/seed_data.dart
//
// Single source of truth for the demo restaurants and riders that the
// app ships with. Both the in-memory AppData store (offline / demo
// mode) and the Firestore seeder read from here, so the online catalog
// and the local cache can never drift apart.
//
// Coordinates are around Tangub City, Misamis Occidental (where the
// system is deployed) so the live maps default to the city.

import 'package:foodhub1/models/order_models.dart';

class SeedRestaurant {
  final String name;
  final String email;
  final String cuisine;
  final String address;
  final double lat;
  final double lng;

  const SeedRestaurant({
    required this.name,
    required this.email,
    required this.cuisine,
    required this.address,
    required this.lat,
    required this.lng,
  });

  GeoPoint get location => GeoPoint(lat, lng);
}

class SeedRider {
  final String name;
  final String email;
  final String vehicle;
  final double lat;
  final double lng;

  const SeedRider({
    required this.name,
    required this.email,
    required this.vehicle,
    required this.lat,
    required this.lng,
  });

  GeoPoint get location => GeoPoint(lat, lng);
}

const List<SeedRestaurant> seedRestaurants = [
  SeedRestaurant(
    name: 'JB LutongBahay Resto',
    email: 'jb@foodhub.com',
    cuisine: 'Filipino, Lutong Bahay',
    address: 'Poblacion, Tangub City, Misamis Occidental',
    lat: 8.0665,
    lng: 123.7498,
  ),
  SeedRestaurant(
    name: 'Bibiana FoodHouse',
    email: 'bibiana@foodhub.com',
    cuisine: 'Filipino, Combo Meals',
    address: 'Provincial Road, Tangub City, Misamis Occidental',
    lat: 8.0632,
    lng: 123.7442,
  ),
  SeedRestaurant(
    name: 'Mamos Tasty Ramen',
    email: 'mamos@foodhub.com',
    cuisine: 'Japanese, Ramen',
    address: 'Tangub–Ozamiz National Highway, Tangub City',
    lat: 8.0682,
    lng: 123.7531,
  ),
  SeedRestaurant(
    name: 'Pareng Eling',
    email: 'pareng@foodhub.com',
    cuisine: 'Filipino, Street Food',
    address: 'Tad-an Road, Tangub City, Misamis Occidental',
    lat: 8.0585,
    lng: 123.7365,
  ),
  SeedRestaurant(
    name: 'Pastilan',
    email: 'pastilan@foodhub.com',
    cuisine: 'Filipino, Pastil',
    address: 'Mimbuaya, Tangub City, Misamis Occidental',
    lat: 8.0715,
    lng: 123.7518,
  ),
];

const List<SeedRider> seedRiders = [
  SeedRider(
    name: 'Ace F. Dumandagan',
    email: 'ace@foodhub.com',
    vehicle: 'Motorcycle',
    lat: 8.0640,
    lng: 123.7460,
  ),
  SeedRider(
    name: 'Jun dela Cruz',
    email: 'jun@foodhub.com',
    vehicle: 'Motorcycle',
    lat: 8.0660,
    lng: 123.7485,
  ),
  SeedRider(
    name: 'Liza Santos',
    email: 'liza@foodhub.com',
    vehicle: 'Bicycle',
    lat: 8.0700,
    lng: 123.7450,
  ),
];