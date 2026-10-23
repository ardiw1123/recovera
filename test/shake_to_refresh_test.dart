import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovera/core/sensors/shake_detector.dart';
import 'package:recovera/data/models/cached_listing_model.dart';
import 'package:recovera/data/repositories/listing_repository.dart';
import 'package:recovera/features/home/screens/home_screen.dart';
import 'package:sensors_plus/sensors_plus.dart';

class MockListingRepositoryForShake extends ListingRepository {
  MockListingRepositoryForShake() : super();

  int getListingsCallCount = 0;
  bool? lastForceRefresh;

  @override
  Future<ListingResult> getListings({
    bool forceRefresh = false,
    String? search,
    String? category,
    double? maxPrice,
    int? minDays,
    String? sort,
    double? lat,
    double? lng,
    double? radiusKm,
  }) async {
    getListingsCallCount++;
    lastForceRefresh = forceRefresh;
    return ListingResult(
      listings: [
        CachedListingModel(
          id: 1,
          productId: 101,
          sellerId: 10,
          batchNumber: 'BATCH-2026-X1',
          qty: 50,
          normalPrice: 20000,
          startPrice: 15000,
          minPrice: 10000,
          currentPrice: 15000,
          dropIntervalMinutes: 60,
          dropPercentage: 5,
          expiryDate: DateTime.now().add(const Duration(days: 10)).toIso8601String(),
          auctionStartAt: DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
          auctionEndAt: DateTime.now().add(const Duration(days: 3)).toIso8601String(),
          status: 'active',
          createdAt: DateTime.now().toIso8601String(),
          productName: 'Yogurt Greek 500g',
          brand: 'FreshDairy',
          category: 'Dairy',
          storageType: 'chilled',
          defaultUnit: 'pcs',
          sellerCompany: 'Fresh Dairy',
          warehouseLat: -6.2,
          warehouseLng: 106.8,
          warehouseCity: 'Jakarta',
          cachedAt: DateTime.now().toIso8601String(),
        ),
      ],
      isFromCache: false,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PBI-13: ShakeDetector Unit Tests', () {
    test('calculateMagnitude computes 3D vector length accurately', () {
      expect(ShakeDetector.calculateMagnitude(0, 0, 0), equals(0.0));
      expect(ShakeDetector.calculateMagnitude(0, 9.8, 0), closeTo(9.8, 0.001));
      // 15^2 + 20^2 = 225 + 400 = 625 => sqrt(625) = 25.0
      expect(
        ShakeDetector.calculateMagnitude(15.0, 20.0, 0.0),
        closeTo(25.0, 0.001),
      );
      // 15^2 + 20^2 + 10^2 = 725 => sqrt(725) ≈ 26.9258
      expect(
        ShakeDetector.calculateMagnitude(15.0, 20.0, 10.0),
        closeTo(26.9258, 0.001),
      );
    });

    test('Triggers onShake when magnitude >= 25.0 m/s²', () async {
      final controller = StreamController<AccelerometerEvent>();
      var shakeCount = 0;

      final detector = ShakeDetector(
        onShake: () => shakeCount++,
        sensorStream: controller.stream,
      );
      detector.startListening();

      // Emit normal gravity (~9.8 m/s²) -> Should NOT trigger
      controller.add(AccelerometerEvent(0, 9.8, 0, DateTime.now()));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(shakeCount, equals(0));

      // Emit gentle movement (~18 m/s²) -> Should NOT trigger
      controller.add(AccelerometerEvent(10, 10, 10, DateTime.now()));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(shakeCount, equals(0));

      // Emit vigorous shake (>= 25 m/s²) -> SHOULD trigger!
      controller.add(AccelerometerEvent(15, 20, 5, DateTime.now()));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(shakeCount, equals(1));

      detector.dispose();
      await controller.close();
    });

    test('Enforces 2-second throttle preventing multiple triggers', () async {
      final controller = StreamController<AccelerometerEvent>();
      var shakeCount = 0;

      final detector = ShakeDetector(
        onShake: () => shakeCount++,
        sensorStream: controller.stream,
        throttleDuration: const Duration(milliseconds: 150),
      );
      detector.startListening();

      // First vigorous shake -> triggers
      controller.add(AccelerometerEvent(18, 18, 10, DateTime.now()));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(shakeCount, equals(1));

      // Immediate second shake within throttle duration -> Ignored!
      controller.add(AccelerometerEvent(20, 20, 10, DateTime.now()));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(shakeCount, equals(1));

      // Wait until throttle expires
      await Future<void>.delayed(const Duration(milliseconds: 160));

      // Third shake after throttle -> triggers again
      controller.add(AccelerometerEvent(18, 18, 10, DateTime.now()));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(shakeCount, equals(2));

      detector.dispose();
      await controller.close();
    });

    test('stopListening prevents onShake from firing', () async {
      final controller = StreamController<AccelerometerEvent>();
      var shakeCount = 0;

      final detector = ShakeDetector(
        onShake: () => shakeCount++,
        sensorStream: controller.stream,
      );
      detector.startListening();
      detector.stopListening();

      controller.add(AccelerometerEvent(25, 20, 10, DateTime.now()));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(shakeCount, equals(0));

      detector.dispose();
      await controller.close();
    });
  });

  group('PBI-13: HomeScreen Shake-to-Refresh Widget Tests', () {
    testWidgets(
      'Shaking device triggers feed refresh, displays snackbar, and calls backend reload',
      (tester) async {
        final mockRepo = MockListingRepositoryForShake();
        final sensorController = StreamController<AccelerometerEvent>();

        await tester.pumpWidget(
          MaterialApp(
            home: HomeScreen(
              repository: mockRepo,
              sensorStream: sensorController.stream,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Initial fetch on mount
        expect(mockRepo.getListingsCallCount, equals(1));

        // Simulate vigorous shake (magnitude = sqrt(16^2 + 20^2 + 5^2) ≈ 26.09 >= 25 m/s²)
        sensorController.add(AccelerometerEvent(16, 20, 5, DateTime.now()));
        await tester.pump(const Duration(milliseconds: 100));

        // Verify snackbar appears with "Memperbarui daftar lelang..."
        expect(find.text('Memperbarui daftar lelang...'), findsOneWidget);

        await tester.pumpAndSettle();

        // Verify repository was called again with forceRefresh: true
        expect(mockRepo.getListingsCallCount, equals(2));
        expect(mockRepo.lastForceRefresh, isTrue);

        await sensorController.close();
      },
    );
  });
}
