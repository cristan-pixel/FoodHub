// lib/services/route_service.dart
//
// Fetches real road routes for the live map using the free public OSRM
// routing API (https://project-osrm.org) and decodes the returned
// polyline with flutter_polyline_points. No API key required, which
// keeps the demo self-contained. Every lookup is cached and all
// failures return null so the map can keep drawing a straight-line
// approximation until a road route is available (or offline).
//
// Besides the polyline, OSRM reports the route's driving `duration`
// and `distance`; those are cached too so the order tracker can show a
// real travel-time estimate without a second network request.

import 'dart:convert';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'package:foodhub1/models/order_models.dart' as models;

/// A road-route measurement returned by [RouteService.estimate].
class RouteEstimate {
  /// Driving time reported by the router (already includes turns/roads).
  final Duration duration;

  /// Route length in metres.
  final double distanceMeters;

  const RouteEstimate({required this.duration, required this.distanceMeters});
}

class RouteService {
  RouteService._();
  static final RouteService instance = RouteService._();

  /// Minimum gap between actual network round-trips for the *same* leg,
  /// so rapid GPS fixes don't hammer the routing server. Throttling is
  /// per origin/destination pair, not global, so two different legs can
  /// be fetched at the same time.
  static const Duration _minFetchInterval = Duration(seconds: 10);

  /// How long a failed/empty lookup stays cached so we don't immediately
  /// re-request the same dead route on every marker move.
  static const Duration _nullCacheTtl = Duration(seconds: 30);

  static const Duration _requestTimeout = Duration(seconds: 15);

  final Map<String, List<models.GeoPoint>?> _cache = {};
  final Map<String, Duration?> _durationCache = {};
  final Map<String, double?> _distanceCache = {};
  final Map<String, DateTime> _cacheAt = {};
  final Map<String, DateTime> _lastFetchAt = {};

  /// Cache key rounds coordinates so near-identical origin/destination
  /// pairs (rider jitter) reuse the same route.
  String _key(models.GeoPoint origin, models.GeoPoint destination) {
    String r(double v) => v.toStringAsFixed(4); // ~11m precision
    return '${r(origin.lat)},${r(origin.lng)}|${r(destination.lat)},${r(destination.lng)}';
  }

  /// Returns the road-route polyline between [origin] and [destination],
  /// or null when routing is unavailable. Caches results per leg.
  Future<List<models.GeoPoint>?> route({
    required models.GeoPoint origin,
    required models.GeoPoint destination,
  }) async {
    final key = _key(origin, destination);
    final cached = _cache[key];
    if (cached != null) return cached;

    final now = DateTime.now();
    final cachedAt = _cacheAt[key];
    if (cachedAt != null && now.difference(cachedAt) < _nullCacheTtl) {
      return cached; // still within the negative-cache window
    }

    // Throttle actual HTTP requests, per leg.
    final lastFetch = _lastFetchAt[key];
    if (lastFetch != null && now.difference(lastFetch) < _minFetchInterval) {
      return cached;
    }
    _lastFetchAt[key] = now;
    _cacheAt[key] = now;

    try {
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${origin.lng},${origin.lat};${destination.lng},${destination.lat}'
        '?overview=full&geometries=polyline',
      );
      final res = await http.get(uri).timeout(_requestTimeout);
      if (res.statusCode != 200) {
        _markMissing(key);
        return null;
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final routes = body['routes'] as List<dynamic>? ?? const [];
      if (routes.isEmpty) {
        _markMissing(key);
        return null;
      }
      final route = routes.first as Map<String, dynamic>;
      final geometry = route['geometry'] as String?;
      if (geometry == null) {
        _markMissing(key);
        return null;
      }
      final points = PolylinePoints.decodePolyline(geometry)
          .map((p) => models.GeoPoint(p.latitude, p.longitude))
          .toList();
      if (points.length < 2) {
        _markMissing(key);
        return null;
      }

      final seconds = (route['duration'] as num?)?.toDouble();
      _durationCache[key] = seconds == null
          ? null
          : Duration(milliseconds: (seconds * 1000).round());
      _distanceCache[key] = (route['distance'] as num?)?.toDouble();

      _cache[key] = points;
      return points;
    } catch (_) {
      // Offline / routing service down / invalid response — never crash
      // the map, just fall back to the straight line.
      _markMissing(key);
      return null;
    }
  }

  /// Returns the routed driving time and distance for a leg. Reuses the
  /// polyline lookup above, so calling this after [route] is free.
  Future<RouteEstimate?> estimate({
    required models.GeoPoint origin,
    required models.GeoPoint destination,
  }) async {
    final key = _key(origin, destination);
    await route(origin: origin, destination: destination);
    final duration = _durationCache[key];
    final distance = _distanceCache[key];
    if (duration == null || distance == null) return null;
    return RouteEstimate(duration: duration, distanceMeters: distance);
  }

  void _markMissing(String key) {
    _cache[key] = null;
    _durationCache[key] = null;
    _distanceCache[key] = null;
    _cacheAt[key] = DateTime.now();
  }
}
