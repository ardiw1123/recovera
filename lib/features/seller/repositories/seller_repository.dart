import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../models/seller_inventory_model.dart';
import '../services/seller_api_service.dart';

/// Repository terpusat untuk alur data Penjual (Inventaris, Unggah, Validasi, Rekomendasi, Publikasi).
class SellerRepository extends ChangeNotifier {
  SellerRepository({required this.apiService});

  final SellerApiService apiService;

  List<SellerListingItem> _inventory = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<SellerListingItem> get inventory => List.unmodifiable(_inventory);
  List<SellerListingItem> get items => inventory;
  int get totalCount => _inventory.length;
  int get activeCount =>
      _inventory.where((i) => i.status.toLowerCase() == 'active').length;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  static SellerRepository? _instance;
  static SellerRepository get instance {
    if (_instance == null) {
      final client = ApiClient();
      _instance = SellerRepository(
        apiService: SellerApiService(client: client),
      );
    }
    return _instance!;
  }

  @visibleForTesting
  static set instance(SellerRepository? repo) => _instance = repo;

  /// Memuat data inventaris riil dari backend endpoint GET /listings/seller/inventory
  Future<List<SellerListingItem>> loadInventory({bool forceRefresh = true}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final items = await apiService.fetchSellerInventory();
      _inventory = items;
      return items;
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Membuat draf produk baru
  Future<Map<String, dynamic>> createDraft(
      SellerDraftCreatePayload payload) async {
    final result = await apiService.createDraft(payload);
    // Tambahkan atau perbarui item di inventaris lokal
    final listing = result['listing'] as SellerListingItem;
    _inventory.removeWhere((item) => item.id == listing.id);
    _inventory.insert(0, listing);
    notifyListeners();
    return result;
  }

  /// Memperbarui draf produk
  Future<Map<String, dynamic>> updateDraft(
    int listingId,
    Map<String, dynamic> patch,
  ) async {
    final result = await apiService.updateDraft(listingId, patch);
    final listing = result['listing'] as SellerListingItem;
    final index = _inventory.indexWhere((item) => item.id == listing.id);
    if (index != -1) {
      _inventory[index] = listing;
    } else {
      _inventory.insert(0, listing);
    }
    notifyListeners();
    return result;
  }

  /// Memvalidasi standar mutu pangan
  Future<SellerValidationResult> validateDraft(int listingId) async {
    return await apiService.validateDraft(listingId);
  }

  /// Mengambil rekomendasi harga AI
  Future<SellerRecommendationResult> getPriceRecommendation(
      int listingId) async {
    return await apiService.getPriceRecommendation(listingId);
  }

  /// Mempublikasikan produk lelang
  Future<SellerListingItem> publishListing(
    int listingId, {
    bool acknowledgePriceWarning = false,
  }) async {
    final published = await apiService.publishListing(
      listingId,
      acknowledgePriceWarning: acknowledgePriceWarning,
    );
    final index = _inventory.indexWhere((item) => item.id == listingId);
    if (index != -1) {
      _inventory[index] = published;
    } else {
      _inventory.insert(0, published);
    }
    notifyListeners();
    return published;
  }
}
