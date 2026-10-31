import 'dart:async';

import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';

import '../../../domain/errors/app_failure.dart';

abstract interface class LocationService {
  Future<String> getCurrentLocation();
}

abstract interface class LocationProvider {
  Future<bool> isServiceEnabled();
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
  Future<Position> getCurrentPosition();
}

abstract interface class ReverseGeocoder {
  Future<List<geocoding.Placemark>> placemarkFromCoordinates(
    double latitude,
    double longitude,
  );
}

class GeolocatorProvider implements LocationProvider {
  const GeolocatorProvider();

  @override
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  @override
  Future<Position> getCurrentPosition() => Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 15),
    ),
  );
}

class GeocodingReverseGeocoder implements ReverseGeocoder {
  GeocodingReverseGeocoder() : _geocoding = geocoding.Geocoding();

  final geocoding.Geocoding _geocoding;

  @override
  Future<List<geocoding.Placemark>> placemarkFromCoordinates(
    double latitude,
    double longitude,
  ) => _geocoding.placemarkFromCoordinates(latitude, longitude);
}

class DeviceLocationService implements LocationService {
  DeviceLocationService({
    LocationProvider? locationProvider,
    ReverseGeocoder? reverseGeocoder,
    this.timeout = const Duration(seconds: 20),
  }) : _locationProvider = locationProvider ?? const GeolocatorProvider(),
       _reverseGeocoder = reverseGeocoder ?? GeocodingReverseGeocoder();

  final LocationProvider _locationProvider;
  final ReverseGeocoder _reverseGeocoder;
  final Duration timeout;
  String? _cachedLocation;
  Future<String>? _locationRequest;

  @override
  Future<String> getCurrentLocation() async {
    final cachedLocation = _cachedLocation;
    if (cachedLocation != null) return cachedLocation;

    final currentRequest = _locationRequest ??= _loadLocation();
    try {
      return await currentRequest;
    } finally {
      if (identical(_locationRequest, currentRequest)) {
        _locationRequest = null;
      }
    }
  }

  Future<String> _loadLocation() async {
    try {
      final location = await _getCurrentLocation().timeout(timeout);
      _cachedLocation = location;
      return location;
    } on LocationFailure {
      rethrow;
    } on TimeoutException {
      throw const LocationTimeoutFailure();
    } on Object catch (error, stackTrace) {
      throw LocationUnavailableFailure(error, stackTrace);
    }
  }

  Future<String> _getCurrentLocation() async {
    if (!await _locationProvider.isServiceEnabled()) {
      throw const LocationServiceDisabledFailure();
    }

    var permission = await _locationProvider.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await _locationProvider.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const LocationPermissionDeniedFailure();
    }

    final position = await _locationProvider.getCurrentPosition();
    late final List<geocoding.Placemark> placemarks;
    try {
      placemarks = await _reverseGeocoder.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
    } on TimeoutException {
      rethrow;
    } on Object {
      throw const GeocodingFailure();
    }
    if (placemarks.isEmpty) throw const GeocodingFailure();
    final placemark = placemarks.first;
    final city = (placemark.locality ?? placemark.subAdministrativeArea)
        ?.trim();
    final state = placemark.administrativeArea?.trim();
    if (city == null || city.isEmpty || state == null || state.isEmpty) {
      throw const GeocodingFailure();
    }
    return '$city, $state';
  }
}
