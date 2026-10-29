// lib/services/location_service.dart
//
// One wrapper around the device's location stack for the whole app.
// Permission handling goes through `permission_handler` (so both the
// rider and customer roles get the standard, graceful OS permission
// flow), while the actual GPS reads/watching use `geolocator`.
//
// Nothing here throws: any platform without a GPS sensor, a user who
// denies/withdraws the permission, or a plugin that isn't wired up on
// desktop all come back as a friendly [LocationPermissionResult] and the
// caller falls back to a demo location / simulated movement.

import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:foodhub1/models/order_models.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// Result of a permission/location-services check.
class LocationPermissionResult {
  const LocationPermissionResult({
    required this.granted,
    this.permanentlyDenied = false,
    this.message,
  });

  /// True when GPS is enabled, the permission is granted, and a fix can
  /// be requested.
  final bool granted;

  /// True when the user selected "Deny permanently" and must re-enable
  /// the permission via system settings.
  final bool permanentlyDenied;

  /// Human-readable reason when [granted] is false.
  final String? message;
}

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  /// Makes sure location services are on and the permission is granted.
  /// Uses permission_handler so the OS-native prompt shows once and each
  /// role (rider picking a delivery, customer pinning an address) gets
  /// the same graceful outcome.
  Future<LocationPermissionResult> requestPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LocationPermissionResult(
          granted: false,
          message: 'Location services are turned off. Please enable GPS.',
        );
      }
      final status = await ph.Permission.location.request();
      if (status.isGranted) {
        return const LocationPermissionResult(granted: true);
      }
      if (status.isPermanentlyDenied) {
        return const LocationPermissionResult(
          granted: false,
          permanentlyDenied: true,
          message:
              'Location permission permanently denied. Enable it in system settings.',
        );
      }
      return LocationPermissionResult(
        granted: false,
        message: status.isDenied
            ? 'Location permission denied.'
            : 'Location access is restricted.',
      );
    } catch (_) {
      // Unsupported platform / no GPS / plugin not wired up — degrade
      // gracefully instead of crashing.
      return const LocationPermissionResult(
        granted: false,
        message: 'Unable to access location.',
      );
    }
  }

  /// Sends the user to the app's system settings page — used after a
  /// permanent denial so they can re-grant location.
  Future<bool> openSettings() => ph.openAppSettings();

  Future<GeoPoint?> getCurrentLocation() async {
    try {
      final result = await requestPermission();
      if (!result.granted) return null;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      return GeoPoint(pos.latitude, pos.longitude);
    } catch (_) {
      // GPS can throw (services off, permission denied, no fix,
      // unsupported platform). Never crash the checkout — callers fall
      // back to a demo location instead.
      return null;
    }
  }

  /// Live stream of GPS fixes — used by the rider dashboard/map to
  /// keep pushing updates into AppData while a delivery is in
  /// progress. Callers should also supply an onError handler: GPS may
  /// drop mid-delivery (permission revoked, sensor offline).
  Stream<GeoPoint> watchLocation() {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // meters between updates
    );
    return Geolocator.getPositionStream(locationSettings: settings)
        .map((pos) => GeoPoint(pos.latitude, pos.longitude));
  }
}