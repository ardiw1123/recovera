import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovera/data/data.dart';
import 'package:recovera/features/auth/screens/location_management_screen.dart';
import 'package:recovera/features/auth/screens/login_screen.dart';
import 'package:recovera/features/auth/screens/profile_screen.dart';
import 'package:recovera/features/auth/screens/register_screen.dart';
import 'package:recovera/features/auth/screens/welcome_screen.dart';
import 'package:recovera/features/feedback/screens/saran_kesan_screen.dart';
import 'package:recovera/features/home/models/product_model.dart';
import 'package:recovera/features/home/screens/home_screen.dart';
import 'package:recovera/features/home/screens/product_detail_screen.dart';
import 'package:recovera/features/home/widgets/filter_bottom_sheet.dart';
import 'package:recovera/features/seller/models/seller_inventory_model.dart';
import 'package:recovera/features/seller/repositories/seller_repository.dart';
import 'package:recovera/features/seller/screens/seller_inventory_screen.dart';
import 'package:recovera/features/seller/screens/upload_stock_flow_screen.dart';
import 'package:recovera/features/seller/services/seller_api_service.dart';
import 'package:recovera/features/shell/main_shell.dart';
import 'package:recovera/features/splash/screens/splash_screen.dart';
import 'package:recovera/features/stok/screens/stok_screen.dart';

CachedListingModel _createTestModel({
  int id = 1,
  String productName = 'Susu UHT Fresh 1L',
  String companyName = 'PT Sumber Dairy Sejahtera',
  String city = 'Jakarta Selatan',
  double distanceKm = 2.5,
  double matchScore = 0.94,
}) {
  return CachedListingModel(
    id: id,
    productId: 100 + id,
    sellerId: 10,
    batchNumber: 'BATCH-2026-X1',
    qty: 250,
    normalPrice: 20000,
    startPrice: 15000,
    minPrice: 10000,
    currentPrice: 12000,
    dropIntervalMinutes: 30,
    dropPercentage: 5,
    expiryDate: DateTime.now().add(const Duration(days: 4)).toIso8601String(),
    auctionStartAt: DateTime.now().subtract(const Duration(hours: 12)).toIso8601String(),
    auctionEndAt: DateTime.now().add(const Duration(days: 3)).toIso8601String(),
    status: 'active',
    createdAt: DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
    productName: productName,
    brand: 'GreenField Fresh',
    category: 'Dairy',
    storageType: 'chilled',
    defaultUnit: 'karton',
    sellerCompany: companyName,
    warehouseLat: -6.2200,
    warehouseLng: 106.8300,
    warehouseCity: city,
    cachedAt: DateTime.now().toIso8601String(),
    distanceKm: distanceKm,
    matchScore: matchScore,
    discountPct: 40.0,
    daysToExpiry: 4,
  );
}

class _AuditListingRepository extends ListingRepository {
  _AuditListingRepository(this.models)
      : super(remoteClient: ListingApiService(client: ApiClient()));

  final List<CachedListingModel> models;

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
    return ListingResult(listings: models, isFromCache: false);
  }

  @override
  Future<CachedListingModel?> getListingById(int id, {bool forceRefresh = false}) async {
    return models.firstWhere((m) => m.id == id, orElse: () => models.first);
  }
}

class _AuditSellerRepository extends SellerRepository {
  _AuditSellerRepository(this.items)
      : super(apiService: SellerApiService(client: ApiClient()));

  final List<SellerListingItem> items;

  @override
  Future<List<SellerListingItem>> loadInventory({bool forceRefresh = true}) async {
    return items;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AuthRepository.instance = AuthRepository(
      authApiService: AuthApiService(client: ApiClient()),
      tokenStorage: InMemoryTokenStorage(),
    );
    SellerRepository.instance = _AuditSellerRepository([]);
  });

  const compactSize = Size(320, 568);
  const smallSize = Size(360, 640);
  const standardSize = Size(390, 844);

  Future<void> testScreenSize(
    WidgetTester tester,
    Widget widget,
    Size size, {
    double keyboardInset = 0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewInsets = FakeViewPadding(bottom: keyboardInset);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
    });

    await tester.pumpWidget(MaterialApp(home: widget));
    await tester.pumpAndSettle();
  }

  group('Layout Overflow Audit', () {
    testWidgets('SplashScreen on compact, small, standard', (tester) async {
      await testScreenSize(tester, const SplashScreen(autoNavigate: false), compactSize);
      await testScreenSize(tester, const SplashScreen(autoNavigate: false), smallSize);
      await testScreenSize(tester, const SplashScreen(autoNavigate: false), standardSize);
    });

    testWidgets('WelcomeScreen on compact, small, standard', (tester) async {
      await testScreenSize(tester, const WelcomeScreen(), compactSize);
      await testScreenSize(tester, const WelcomeScreen(), smallSize);
      await testScreenSize(tester, const WelcomeScreen(), standardSize);
    });

    testWidgets('LoginScreen on compact, small, standard, and keyboard active', (tester) async {
      await testScreenSize(tester, const LoginScreen(), compactSize);
      await testScreenSize(tester, const LoginScreen(), smallSize);
      await testScreenSize(tester, const LoginScreen(), standardSize);
      await testScreenSize(tester, const LoginScreen(), smallSize, keyboardInset: 300);
      await testScreenSize(tester, const LoginScreen(), compactSize, keyboardInset: 260);
    });

    testWidgets('RegisterScreen on compact, small, standard, and keyboard active', (tester) async {
      await testScreenSize(tester, const RegisterScreen(), compactSize);
      await testScreenSize(tester, const RegisterScreen(), smallSize);
      await testScreenSize(tester, const RegisterScreen(), standardSize);
      await testScreenSize(tester, const RegisterScreen(), smallSize, keyboardInset: 300);
      await testScreenSize(tester, const RegisterScreen(), compactSize, keyboardInset: 260);
    });

    testWidgets('ProfileScreen on compact, small, standard', (tester) async {
      await testScreenSize(tester, const ProfileScreen(), compactSize);
      await testScreenSize(tester, const ProfileScreen(), smallSize);
      await testScreenSize(tester, const ProfileScreen(), standardSize);
    });

    testWidgets('LocationManagementScreen on compact, small, standard, and keyboard active', (tester) async {
      await testScreenSize(tester, const LocationManagementScreen(), compactSize);
      await testScreenSize(tester, const LocationManagementScreen(), smallSize);
      await testScreenSize(tester, const LocationManagementScreen(), standardSize);
      await testScreenSize(tester, const LocationManagementScreen(), smallSize, keyboardInset: 300);
      await testScreenSize(tester, const LocationManagementScreen(), compactSize, keyboardInset: 260);
    });

    testWidgets('HomeScreen on compact, small, standard', (tester) async {
      final fakeListingRepo = _AuditListingRepository([_createTestModel()]);
      await testScreenSize(tester, HomeScreen(repository: fakeListingRepo), compactSize);
      await testScreenSize(tester, HomeScreen(repository: fakeListingRepo), smallSize);
      await testScreenSize(tester, HomeScreen(repository: fakeListingRepo), standardSize);
    });

    testWidgets('ProductDetailScreen on compact, small, standard', (tester) async {
      final model = _createTestModel();
      final fakeListingRepo = _AuditListingRepository([model]);
      final listing = Listing.fromCachedModel(model);
      await testScreenSize(tester, ProductDetailScreen(listing: listing, listingRepository: fakeListingRepo), compactSize);
      await testScreenSize(tester, ProductDetailScreen(listing: listing, listingRepository: fakeListingRepo), smallSize);
      await testScreenSize(tester, ProductDetailScreen(listing: listing, listingRepository: fakeListingRepo), standardSize);
    });

    testWidgets('SellerInventoryScreen on compact, small, standard', (tester) async {
      final testItem = SellerListingItem(
        id: 1,
        productId: 101,
        batchNumber: 'LOT-2026-X1',
        qty: 500,
        normalPrice: 18000,
        startPrice: 15000,
        minPrice: 10000,
        currentPrice: 10800,
        expiryDate: DateTime.now().add(const Duration(days: 45)).toIso8601String(),
        status: 'active',
        createdAt: DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        productName: 'Susu UHT Full Cream Ultra Milk Premium 1000ml',
        category: 'Produk Olahan Susu & Dairy',
        defaultUnit: 'box',
      );
      final fakeSellerRepo = _AuditSellerRepository([testItem]);
      await testScreenSize(tester, SellerInventoryScreen(repository: fakeSellerRepo), compactSize);
      await testScreenSize(tester, SellerInventoryScreen(repository: fakeSellerRepo), smallSize);
      await testScreenSize(tester, SellerInventoryScreen(repository: fakeSellerRepo), standardSize);
    });

    testWidgets('UploadStockFlowScreen on compact, small, standard, and keyboard active', (tester) async {
      final testItem = SellerListingItem(
        id: 1,
        productId: 101,
        batchNumber: 'LOT-2026-X1',
        qty: 500,
        normalPrice: 18000,
        startPrice: 15000,
        minPrice: 10000,
        currentPrice: 10800,
        expiryDate: DateTime.now().add(const Duration(days: 45)).toIso8601String(),
        status: 'active',
        createdAt: DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        productName: 'Susu UHT Full Cream Ultra Milk Premium 1000ml',
        category: 'Produk Olahan Susu & Dairy',
        defaultUnit: 'box',
      );
      final fakeSellerRepo = _AuditSellerRepository([testItem]);
      await testScreenSize(tester, UploadStockFlowScreen(repository: fakeSellerRepo), compactSize);
      await testScreenSize(tester, UploadStockFlowScreen(repository: fakeSellerRepo), smallSize);
      await testScreenSize(tester, UploadStockFlowScreen(repository: fakeSellerRepo), standardSize);
      await testScreenSize(tester, UploadStockFlowScreen(repository: fakeSellerRepo), smallSize, keyboardInset: 300);
      await testScreenSize(tester, UploadStockFlowScreen(repository: fakeSellerRepo), compactSize, keyboardInset: 260);
    });

    testWidgets('MainShell (buyer & seller) on compact, small, standard', (tester) async {
      final fakeListingRepo = _AuditListingRepository([_createTestModel()]);
      final fakeSellerRepo = _AuditSellerRepository([]);
      // Buyer shell
      await testScreenSize(tester, MainShell(listingRepository: fakeListingRepo, sellerRepository: fakeSellerRepo), compactSize);
      await testScreenSize(tester, MainShell(listingRepository: fakeListingRepo, sellerRepository: fakeSellerRepo), smallSize);
      await testScreenSize(tester, MainShell(listingRepository: fakeListingRepo, sellerRepository: fakeSellerRepo), standardSize);

      // Seller shell
      AuthRepository.instance.currentUserProfile = const UserProfile(
        id: 99,
        email: 'seller@test.com',
        role: 'seller',
        name: 'Seller Test',
      );
      await testScreenSize(tester, MainShell(listingRepository: fakeListingRepo, sellerRepository: fakeSellerRepo), compactSize);
      await testScreenSize(tester, MainShell(listingRepository: fakeListingRepo, sellerRepository: fakeSellerRepo), smallSize);
      await testScreenSize(tester, MainShell(listingRepository: fakeListingRepo, sellerRepository: fakeSellerRepo), standardSize);
    });

    testWidgets('StokScreen on compact, small, standard', (tester) async {
      final fakeListingRepo = _AuditListingRepository([_createTestModel()]);
      await testScreenSize(tester, StokScreen(listingRepository: fakeListingRepo), compactSize);
      await testScreenSize(tester, StokScreen(listingRepository: fakeListingRepo), smallSize);
      await testScreenSize(tester, StokScreen(listingRepository: fakeListingRepo), standardSize);
    });

    testWidgets('SaranKesanScreen on compact, small, standard, and keyboard active', (tester) async {
      await testScreenSize(tester, const SaranKesanScreen(), compactSize);
      await testScreenSize(tester, const SaranKesanScreen(), smallSize);
      await testScreenSize(tester, const SaranKesanScreen(), standardSize);
      await testScreenSize(tester, const SaranKesanScreen(), smallSize, keyboardInset: 300);
      await testScreenSize(tester, const SaranKesanScreen(), compactSize, keyboardInset: 260);
    });

    testWidgets('FilterBottomSheet on compact, small, standard', (tester) async {
      Widget sheet = Scaffold(
        body: FilterBottomSheet(
          selectedCategories: const {},
          selectedExpiryPreset: 'all',
          selectedSort: 'cheapest',
          onApply: (cats, exp, sort, dist) {},
        ),
      );
      await testScreenSize(tester, sheet, compactSize);
      await testScreenSize(tester, sheet, smallSize);
      await testScreenSize(tester, sheet, standardSize);
    });
  });
}
