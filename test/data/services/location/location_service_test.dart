import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:o_que_comer_app/data/services/location/location_service.dart';
import 'package:o_que_comer_app/domain/errors/app_failure.dart';

class FakeLocationProvider implements LocationProvider {
  FakeLocationProvider({
    this.enabled = true,
    this.permission = LocationPermission.whileInUse,
    this.requestedPermission = LocationPermission.whileInUse,
    Position? position,
  }) : position =
           position ??
           Position(
             latitude: -25.4284,
             longitude: -49.2733,
             timestamp: DateTime.now(),
             accuracy: 10,
             altitude: 0,
             altitudeAccuracy: 1,
             heading: 0,
             headingAccuracy: 1,
             speed: 0,
             speedAccuracy: 1,
             floor: null,
             isMocked: true,
           );

  bool enabled;
  LocationPermission permission;
  LocationPermission requestedPermission;
  final Position position;
  Object? error;
  int positionRequests = 0;

  @override
  Future<bool> isServiceEnabled() async => enabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    permission = requestedPermission;
    return requestedPermission;
  }

  @override
  Future<Position> getCurrentPosition() async {
    positionRequests++;
    if (error != null) throw Exception(error);
    return position;
  }
}

class FakeReverseGeocoder implements ReverseGeocoder {
  List<Placemark> placemarks = const [
    Placemark(locality: 'Curitiba', administrativeArea: 'PR'),
  ];
  Object? error;
  Duration delay = Duration.zero;
  int requests = 0;

  @override
  Future<List<Placemark>> placemarkFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    requests++;
    await Future<void>.delayed(delay);
    if (error != null) throw Exception(error);
    return placemarks;
  }
}

void main() {
  test('returns city and state after reverse geocoding', () async {
    final service = DeviceLocationService(
      locationProvider: FakeLocationProvider(),
      reverseGeocoder: FakeReverseGeocoder(),
    );

    expect(await service.getCurrentLocation(), 'Curitiba, PR');
  });

  test('uses the administrative subdivision as city fallback', () async {
    final geocoder = FakeReverseGeocoder()
      ..placemarks = const [
        Placemark(
          administrativeArea: 'Paraná',
          subAdministrativeArea: 'Curitiba',
        ),
      ];
    final service = DeviceLocationService(
      locationProvider: FakeLocationProvider(),
      reverseGeocoder: geocoder,
    );

    expect(await service.getCurrentLocation(), 'Curitiba, Paraná');
  });

  test('caches a successful location lookup', () async {
    final provider = FakeLocationProvider();
    final geocoder = FakeReverseGeocoder();
    final service = DeviceLocationService(
      locationProvider: provider,
      reverseGeocoder: geocoder,
    );

    await service.getCurrentLocation();
    await service.getCurrentLocation();

    expect(provider.positionRequests, 1);
    expect(geocoder.requests, 1);
  });

  test('returns a distinct failure when permission is denied', () async {
    final service = DeviceLocationService(
      locationProvider: FakeLocationProvider(
        permission: LocationPermission.deniedForever,
      ),
      reverseGeocoder: FakeReverseGeocoder(),
    );

    expect(
      () => service.getCurrentLocation(),
      throwsA(isA<LocationPermissionDeniedFailure>()),
    );
  });

  test('requests permission when it is initially denied', () async {
    final provider = FakeLocationProvider(
      permission: LocationPermission.denied,
      requestedPermission: LocationPermission.whileInUse,
    );
    final service = DeviceLocationService(
      locationProvider: provider,
      reverseGeocoder: FakeReverseGeocoder(),
    );

    expect(await service.getCurrentLocation(), 'Curitiba, PR');
    expect(provider.positionRequests, 1);
  });

  test('returns a distinct failure when GPS is disabled', () async {
    final service = DeviceLocationService(
      locationProvider: FakeLocationProvider(enabled: false),
      reverseGeocoder: FakeReverseGeocoder(),
    );

    expect(
      () => service.getCurrentLocation(),
      throwsA(isA<LocationServiceDisabledFailure>()),
    );
  });

  test('returns a distinct failure when geocoding has no result', () async {
    final geocoder = FakeReverseGeocoder()..placemarks = const [];
    final service = DeviceLocationService(
      locationProvider: FakeLocationProvider(),
      reverseGeocoder: geocoder,
    );

    expect(
      () => service.getCurrentLocation(),
      throwsA(isA<GeocodingFailure>()),
    );
  });

  test('returns a distinct failure when geocoding throws', () async {
    final geocoder = FakeReverseGeocoder()..error = StateError('unavailable');
    final service = DeviceLocationService(
      locationProvider: FakeLocationProvider(),
      reverseGeocoder: geocoder,
    );

    expect(
      () => service.getCurrentLocation(),
      throwsA(isA<GeocodingFailure>()),
    );
  });

  test('rejects a placemark without city or state', () async {
    final geocoder = FakeReverseGeocoder()
      ..placemarks = const [Placemark(locality: 'Curitiba')];
    final service = DeviceLocationService(
      locationProvider: FakeLocationProvider(),
      reverseGeocoder: geocoder,
    );

    expect(
      () => service.getCurrentLocation(),
      throwsA(isA<GeocodingFailure>()),
    );
  });

  test('shares an in-flight lookup between concurrent callers', () async {
    final provider = FakeLocationProvider();
    final geocoder = FakeReverseGeocoder()
      ..delay = const Duration(milliseconds: 10);
    final service = DeviceLocationService(
      locationProvider: provider,
      reverseGeocoder: geocoder,
    );

    final locations = await Future.wait([
      service.getCurrentLocation(),
      service.getCurrentLocation(),
    ]);

    expect(locations, ['Curitiba, PR', 'Curitiba, PR']);
    expect(provider.positionRequests, 1);
    expect(geocoder.requests, 1);
  });

  test('returns a distinct failure on timeout', () async {
    final geocoder = FakeReverseGeocoder()
      ..delay = const Duration(milliseconds: 50);
    final service = DeviceLocationService(
      locationProvider: FakeLocationProvider(),
      reverseGeocoder: geocoder,
      timeout: const Duration(milliseconds: 1),
    );

    expect(
      () => service.getCurrentLocation(),
      throwsA(isA<LocationTimeoutFailure>()),
    );
  });
}
