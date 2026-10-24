import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/services/device_location_service.dart';
import '../../../core/services/place_search_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/auth_repository.dart';

/// PBI-03 / ARDI-95 — Layar Manajemen Lokasi, Izin GPS & Pin Peta Interaktif
///
/// Menyediakan pengalaman visual dan interaktif bagi pengguna (khususnya Buyer):
/// 1. Peta Interaktif Nyata dengan flutter_map & OpenStreetMap (TileLayer)
/// 2. Pin Marker Interaktif yang sinkron dengan titik koordinat dan alamat
/// 3. Fitur Pencarian Tempat (jalan, tempat, kota) dengan Nominatim API
/// 4. Izin Lokasi Native Handset: Pengecekan dan permintaan izin GPS mobile
/// 5. Quick selector kota-kota utama Indonesia dengan koordinat geografis nyata
/// 6. Validasi form alamat & koordinat, penyimpanan persisten ke backend via AuthRepository (PATCH /profile)
class LocationManagementScreen extends StatefulWidget {
  const LocationManagementScreen({
    super.key,
    this.initialAddress,
    this.initialCity,
    this.initialLat,
    this.initialLng,
    this.deviceLocationService,
    this.placeSearchService,
    this.autoPromptPermission = true,
  });

  final String? initialAddress;
  final String? initialCity;
  final double? initialLat;
  final double? initialLng;
  final DeviceLocationService? deviceLocationService;
  final PlaceSearchService? placeSearchService;
  final bool autoPromptPermission;

  @override
  State<LocationManagementScreen> createState() => _LocationManagementScreenState();
}

class _LocationManagementScreenState extends State<LocationManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _addressCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _latCtrl;
  late final TextEditingController _lngCtrl;
  late final TextEditingController _searchCtrl;
  late final MapController _mapController;

  late final DeviceLocationService _locationService;
  late final PlaceSearchService _placeSearchService;

  double _currentLat = -6.2088;
  double _currentLng = 106.8456;

  bool _isSaving = false;
  bool _isManualInput = false;
  bool _permissionDenied = false;
  bool _hasPromptedPermission = false;
  bool _addressEmptyError = false;

  bool _isSearching = false;
  List<PlaceSearchResult> _searchResults = [];

  static const List<Map<String, dynamic>> _presetCities = [
    {'name': 'Jakarta Pusat', 'lat': -6.1754, 'lng': 106.8272, 'address': 'Jl. Medan Merdeka Barat No. 1, Jakarta Pusat'},
    {'name': 'Jakarta Selatan', 'lat': -6.2615, 'lng': 106.8106, 'address': 'Jl. Kemang Raya No. 18, Jakarta Selatan'},
    {'name': 'Depok', 'lat': -6.4025, 'lng': 106.7942, 'address': 'Jl. Margonda Raya No. 42, Depok'},
    {'name': 'Surabaya', 'lat': -7.2575, 'lng': 112.7521, 'address': 'Jl. Pemuda No. 33, Genteng, Surabaya'},
    {'name': 'Bandung', 'lat': -6.9175, 'lng': 107.6191, 'address': 'Jl. Asia Afrika No. 65, Bandung'},
    {'name': 'Tangerang', 'lat': -6.1783, 'lng': 106.6319, 'address': 'Jl. Daan Mogot No. 88, Tangerang'},
    {'name': 'Yogyakarta', 'lat': -7.7956, 'lng': 110.3695, 'address': 'Jl. Malioboro No. 56, Yogyakarta'},
    {'name': 'Semarang', 'lat': -6.9932, 'lng': 110.4203, 'address': 'Jl. Pandanaran No. 12, Semarang'},
  ];

  @override
  void initState() {
    super.initState();
    _locationService = widget.deviceLocationService ?? DeviceLocationService.instance;
    _placeSearchService = widget.placeSearchService ?? PlaceSearchService.instance;
    _mapController = MapController();
    _searchCtrl = TextEditingController();

    final profile = AuthRepository.instance.currentUserProfile;

    _currentLat = widget.initialLat ?? profile?.lat ?? -6.2088;
    _currentLng = widget.initialLng ?? profile?.lng ?? 106.8456;

    final initialAddr = widget.initialAddress ??
        profile?.address ??
        'Jl. Gatot Subroto No. 45, Jakarta Pusat';
    final initialCt = widget.initialCity ?? profile?.city ?? 'Jakarta Pusat';

    _addressCtrl = TextEditingController(text: initialAddr);
    _cityCtrl = TextEditingController(text: initialCt);
    _latCtrl = TextEditingController(text: _currentLat.toStringAsFixed(6));
    _lngCtrl = TextEditingController(text: _currentLng.toStringAsFixed(6));

    _addressCtrl.addListener(() {
      if (_addressCtrl.text.trim().isNotEmpty && _addressEmptyError) {
        setState(() => _addressEmptyError = false);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialPermission();
    });
  }

  Future<void> _checkInitialPermission() async {
    if (!mounted) return;
    try {
      final status = await _locationService.checkPermission();
      if (status == LocationPermissionStatus.granted) {
        setState(() {
          _hasPromptedPermission = true;
          _permissionDenied = false;
        });
      } else if (status == LocationPermissionStatus.denied || status == LocationPermissionStatus.deniedForever) {
        setState(() {
          _hasPromptedPermission = true;
          _permissionDenied = true;
        });
      }
    } catch (_) {
      // Abaikan pada pengujian lingkungan non-native
    }
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _searchCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onCitySelected(Map<String, dynamic> city) {
    final lat = city['lat'] as double;
    final lng = city['lng'] as double;
    final name = city['name'] as String;
    final addr = city['address'] as String;

    setState(() {
      _currentLat = lat;
      _currentLng = lng;
      _latCtrl.text = lat.toStringAsFixed(6);
      _lngCtrl.text = lng.toStringAsFixed(6);
      _cityCtrl.text = name;
      _addressCtrl.text = addr;
      _addressEmptyError = false;
    });

    try {
      _mapController.move(LatLng(lat, lng), 15.0);
    } catch (_) {}
  }

  void _onPanMap(DragUpdateDetails details) {
    const sensitivity = 0.0003;
    setState(() {
      _currentLat -= details.delta.dy * sensitivity;
      _currentLng += details.delta.dx * sensitivity;
      _latCtrl.text = _currentLat.toStringAsFixed(6);
      _lngCtrl.text = _currentLng.toStringAsFixed(6);
    });

    try {
      _mapController.move(LatLng(_currentLat, _currentLng), _mapController.camera.zoom);
    } catch (_) {}
  }

  Future<void> _reverseGeocodeCurrentLocation() async {
    try {
      final res = await _placeSearchService.reverseGeocode(_currentLat, _currentLng);
      if (mounted) {
        setState(() {
          _addressCtrl.text = res.road;
          _cityCtrl.text = res.city;
          _addressEmptyError = false;
        });
      }
    } catch (_) {}
  }

  Future<void> _acquireGpsLocation() async {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: const Key('snack_gps_loading'),
        content: Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Mengakses sensor GPS dan memproses alamat...',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );

    try {
      final loc = await _locationService.getCurrentLocation();
      if (!mounted) return;

      setState(() {
        _currentLat = loc.latitude;
        _currentLng = loc.longitude;
        _latCtrl.text = loc.latitude.toStringAsFixed(6);
        _lngCtrl.text = loc.longitude.toStringAsFixed(6);
        _addressCtrl.text = loc.address;
        _cityCtrl.text = loc.city;
        _addressEmptyError = false;
      });

      try {
        _mapController.move(LatLng(loc.latitude, loc.longitude), 15.0);
      } catch (_) {}

      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('snack_gps_success'),
          content: Row(
            children: [
              const Icon(Icons.my_location_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Lokasi GPS berhasil diperoleh: ${loc.city}',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('snack_gps_error'),
          content: Text(
            'Gagal memperoleh lokasi GPS: $e',
            style: GoogleFonts.inter(fontSize: 12),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showExpandedMapDialog() {
    double tempLat = _currentLat;
    double tempLng = _currentLng;
    final MapController dialogMapController = MapController();

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Container(
                  width: double.infinity,
                  height: MediaQuery.of(context).size.height * 0.75,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.map_rounded, color: AppColors.primary, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Perluas Peta Lokasi',
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.darkNavy,
                                      ),
                                    ),
                                    Text(
                                      'Geser atau ketuk peta untuk memindahkan pin lokasi',
                                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.slateText),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () => Navigator.of(dialogCtx).pop(),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Stack(
                            children: [
                              FlutterMap(
                                mapController: dialogMapController,
                                options: MapOptions(
                                  initialCenter: LatLng(tempLat, tempLng),
                                  initialZoom: 15.0,
                                  minZoom: 3.0,
                                  maxZoom: 18.0,
                                  interactionOptions: const InteractionOptions(
                                    flags: InteractiveFlag.all,
                                  ),
                                  onTap: (tapPosition, point) {
                                    setDialogState(() {
                                      tempLat = point.latitude;
                                      tempLng = point.longitude;
                                    });
                                  },
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName: 'com.recovera.app',
                                  ),
                                  MarkerLayer(
                                    markers: [
                                      Marker(
                                        point: LatLng(tempLat, tempLng),
                                        width: 52,
                                        height: 52,
                                        alignment: Alignment.topCenter,
                                        child: const Icon(
                                          Icons.location_on_rounded,
                                          size: 48,
                                          color: Color(0xFFEA4335),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Positioned.fill(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onPanUpdate: (details) {
                                    const sensitivity = 0.0003;
                                    setDialogState(() {
                                      tempLat -= details.delta.dy * sensitivity;
                                      tempLng += details.delta.dx * sensitivity;
                                    });
                                    try {
                                      dialogMapController.move(LatLng(tempLat, tempLng), dialogMapController.camera.zoom);
                                    } catch (_) {}
                                  },
                                ),
                              ),
                              Positioned(
                                top: 12,
                                left: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.95),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.explore_rounded, size: 14, color: AppColors.primary),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Lat: ${tempLat.toStringAsFixed(4)}, Lng: ${tempLng.toStringAsFixed(4)}',
                                        style: GoogleFonts.robotoMono(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.darkNavy,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 12,
                                right: 12,
                                child: Column(
                                  children: [
                                    _buildMapActionButton(
                                      key: const Key('btn_dialog_zoom_in'),
                                      icon: Icons.add_rounded,
                                      tooltip: 'Zoom In',
                                      onTap: () {
                                        try {
                                          final nextZoom = (dialogMapController.camera.zoom + 1.0).clamp(3.0, 18.0);
                                          dialogMapController.move(dialogMapController.camera.center, nextZoom);
                                        } catch (_) {}
                                      },
                                    ),
                                    const SizedBox(height: 6),
                                    _buildMapActionButton(
                                      key: const Key('btn_dialog_zoom_out'),
                                      icon: Icons.remove_rounded,
                                      tooltip: 'Zoom Out',
                                      onTap: () {
                                        try {
                                          final prevZoom = (dialogMapController.camera.zoom - 1.0).clamp(3.0, 18.0);
                                          dialogMapController.move(dialogMapController.camera.center, prevZoom);
                                        } catch (_) {}
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              key: const Key('btn_confirm_dialog_location'),
                              icon: const Icon(Icons.check_rounded, size: 18),
                              label: Text(
                                'Gunakan Titik Lokasi Ini',
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              onPressed: () async {
                                Navigator.of(dialogCtx).pop();
                                setState(() {
                                  _currentLat = tempLat;
                                  _currentLng = tempLng;
                                  _latCtrl.text = tempLat.toStringAsFixed(6);
                                  _lngCtrl.text = tempLng.toStringAsFixed(6);
                                  _addressEmptyError = false;
                                });
                                try {
                                  _mapController.move(LatLng(tempLat, tempLng), 15.0);
                                } catch (_) {}
                                await _reverseGeocodeCurrentLocation();
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _handleGpsLocation() {
    if (_permissionDenied) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('snack_permission_denial'),
          content: Container(
            key: const Key('snack_permission_denied'),
            child: Row(
              children: [
                const Icon(Icons.location_off_rounded, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Izin akses lokasi ditolak oleh sistem. Silakan pilih titik pada peta atau isi formulir manual.',
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _locationService.requestPermission().then((status) {
      if (!mounted) return;
      if (status == LocationPermissionStatus.denied ||
          status == LocationPermissionStatus.deniedForever) {
        setState(() {
          _permissionDenied = true;
          _hasPromptedPermission = true;
        });
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            key: const Key('snack_permission_denial'),
            content: Container(
              key: const Key('snack_permission_denied'),
              child: Row(
                children: [
                  const Icon(Icons.location_off_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Izin akses lokasi ditolak oleh sistem. Silakan pilih titik pada peta atau isi formulir manual.',
                      style: GoogleFonts.inter(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }).catchError((_) {});

    _acquireGpsLocation();
  }

  Future<void> _performPlaceSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchResults = [];
    });

    try {
      final results = await _placeSearchService.searchPlaces(trimmed);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
      });

      if (results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Lokasi "$trimmed" tidak ditemukan. Coba kata kunci lain.',
              style: GoogleFonts.inter(fontSize: 12),
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      // Error jaringan ditangani secara aman
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _onSelectPlaceResult(PlaceSearchResult result) {
    FocusScope.of(context).unfocus();
    setState(() {
      _currentLat = result.latitude;
      _currentLng = result.longitude;
      _latCtrl.text = result.latitude.toStringAsFixed(6);
      _lngCtrl.text = result.longitude.toStringAsFixed(6);
      _addressCtrl.text = result.displayName;
      _searchResults = [];
      _searchCtrl.clear();
      _addressEmptyError = false;
    });

    try {
      _mapController.move(LatLng(result.latitude, result.longitude), 16.0);
    } catch (_) {}
  }

  Future<void> _saveLocation() async {
    final isAddrEmpty = _addressCtrl.text.trim().isEmpty;
    setState(() {
      _addressEmptyError = isAddrEmpty;
    });

    final valid = _formKey.currentState!.validate();
    if (!valid) return;

    final lat = double.tryParse(_latCtrl.text.trim()) ?? _currentLat;
    final lng = double.tryParse(_lngCtrl.text.trim()) ?? _currentLng;
    final address = _addressCtrl.text.trim();
    final city = _cityCtrl.text.trim().isNotEmpty ? _cityCtrl.text.trim() : null;

    setState(() => _isSaving = true);

    try {
      await AuthRepository.instance.updateLocation(
        address: address,
        latitude: lat,
        longitude: lng,
        city: city,
        allowOfflineFallback: true,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('snack_save_success'),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Lokasi & koordinat berhasil disimpan!',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      // Handle offline condition gracefully
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('snack_save_offline'),
          content: Row(
            children: [
              const Icon(Icons.cloud_off_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Mode Offline: Tersimpan di perangkat lokal (sesi lokal perangkat).',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFD97706),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );

      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = AuthRepository.instance.currentUserProfile;
    final activeAddress = profile?.address ?? _addressCtrl.text;
    final activeLat = profile?.lat ?? _currentLat;
    final activeLng = profile?.lng ?? _currentLng;

    return Scaffold(
      key: const Key('location_management_screen'),
      backgroundColor: AppColors.canvasBg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Lokasi & Pengiriman',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              'Atur Lokasi Pengiriman',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
        leading: IconButton(
          key: const Key('btn_back_location'),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            key: const Key('toggle_map_mode'),
            tooltip: _isManualInput ? 'Tampilkan Peta' : 'Input Manual',
            icon: Icon(
              _isManualInput ? Icons.map_rounded : Icons.edit_location_alt_rounded,
              color: Colors.white,
            ),
            onPressed: () => setState(() => _isManualInput = !_isManualInput),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: _buildSaveButton(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Current Active Location Banner ────────────────────────
                  _buildCurrentLocationCard(activeAddress, activeLat, activeLng),
                  const SizedBox(height: 8),

                  // ── Mode Switch & Map / Manual Container ──────────────────
                  if (!_isManualInput) ...[
                    _buildGoogleMapsInteractiveSection(),
                    const SizedBox(height: 8),
                    _buildQuickCityPresets(),
                    const SizedBox(height: 8),
                    if (!_hasPromptedPermission && !_permissionDenied)
                      _buildPermissionPromptBanner(),
                    if (_permissionDenied)
                      _buildPermissionDeniedNotice(),
                    const SizedBox(height: 8),
                    _buildCoordinateDisplayCard(),
                  ] else ...[
                    _buildManualCoordinateSection(),
                    const SizedBox(height: 12),
                    _buildQuickCityPresets(),
                    if (_permissionDenied)
                      _buildPermissionDeniedNotice(),
                  ],

                  const SizedBox(height: 16),

                  // ── Form Alamat & Detail Geocoding ────────────────────────
                  _buildAddressFormFields(),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Komponen Banner Permintaan Izin Lokasi Handset
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildPermissionPromptBanner() {
    return Container(
      key: const Key('location_permission_prompt_banner'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Container(
        key: const Key('location_permission_prompt'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.near_me_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Izin Akses Lokasi Perangkat',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkNavy,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Izinkan aplikasi mendeteksi koordinat GPS outlet Anda secara otomatis untuk kemudahan penjemputan dan pengiriman pangan.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.slateText,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  key: const Key('btn_deny_location_permission'),
                  onPressed: () {
                    setState(() {
                      _hasPromptedPermission = true;
                      _permissionDenied = true;
                    });
                  },
                  child: Text(
                    'Tolak',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slateText,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  key: const Key('btn_grant_location_permission'),
                  icon: const Icon(Icons.my_location_rounded, size: 14),
                  label: Text(
                    'Izinkan Lokasi',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    setState(() {
                      _hasPromptedPermission = true;
                    });
                    final status = await _locationService.requestPermission();
                    if (status == LocationPermissionStatus.granted) {
                      setState(() {
                        _permissionDenied = false;
                      });
                      _acquireGpsLocation();
                    } else {
                      setState(() {
                        _permissionDenied = true;
                      });
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Komponen Kartu Lokasi Aktif
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildCurrentLocationCard(String address, double lat, double lng) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.store_mall_directory_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Titik Alamat Aktif',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slateText,
                      ),
                    ),
                    Text(
                      address,
                      key: const Key('current_location_address'),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkNavy,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.gps_fixed_rounded, size: 14, color: AppColors.secondary),
                  const SizedBox(width: 4),
                  Text(
                    '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                    key: const Key('current_location_coordinates'),
                    style: GoogleFonts.robotoMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Text(
                  'Radius Rekomendasi 15 km',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Komponen Interaktif Flutter Map (OpenStreetMap) di Ponsel dengan Marker & Search
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildGoogleMapsInteractiveSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Peta Interaktif Google Maps',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkNavy,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Simulasi Izin Ditolak',
                  style: GoogleFonts.inter(fontSize: 10, color: AppColors.slateText),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  height: 24,
                  child: Switch(
                    key: const Key('toggle_permission_denial'),
                    value: _permissionDenied,
                    onChanged: (val) => setState(() {
                      _permissionDenied = val;
                      if (val) _hasPromptedPermission = true;
                    }),
                    activeThumbColor: AppColors.error,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),

        // ── Search Bar Input Tempat ─────────────────────────────────────────
        _buildSearchBar(),
        const SizedBox(height: 6),

        // ── Container Visual Kanvas Peta ────────────────────────────────────
        Container(
          key: const Key('map_interactive_container'),
          height: 320,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFE5E7EB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Stack(
              children: [
                // Peta Interaktif Flutter Map (OpenStreetMap)
                Positioned.fill(
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: LatLng(_currentLat, _currentLng),
                      initialZoom: 15.0,
                      minZoom: 3.0,
                      maxZoom: 18.0,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all,
                      ),
                      onTap: (tapPosition, point) async {
                        setState(() {
                          _currentLat = point.latitude;
                          _currentLng = point.longitude;
                          _latCtrl.text = point.latitude.toStringAsFixed(6);
                          _lngCtrl.text = point.longitude.toStringAsFixed(6);
                          _addressEmptyError = false;
                        });
                        await _reverseGeocodeCurrentLocation();
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.recovera.app',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(_currentLat, _currentLng),
                            width: 48,
                            height: 48,
                            alignment: Alignment.topCenter,
                            child: const Icon(
                              Icons.location_on_rounded,
                              key: Key('map_pin_indicator'),
                              size: 42,
                              color: Color(0xFFEA4335),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Touch / Pan Gesture Handler untuk kompatibilitas gesture drag & testing
                Positioned.fill(
                  child: GestureDetector(
                    key: const Key('map_touch_detector'),
                    behavior: HitTestBehavior.translucent,
                    onPanUpdate: _onPanMap,
                    onPanEnd: (_) => _reverseGeocodeCurrentLocation(),
                  ),
                ),

                // HUD Koordinat Real-Time di Atas Peta
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    key: const Key('map_coordinates_hud'),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.explore_rounded, size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Lat: ${_currentLat.toStringAsFixed(4)}, Lng: ${_currentLng.toStringAsFixed(4)}',
                          style: GoogleFonts.robotoMono(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.darkNavy,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Watermark / Atribusi di Pojok Kiri Bawah
                Positioned(
                  bottom: 8,
                  left: 10,
                  child: Container(
                    key: const Key('google_maps_watermark'),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.map_outlined, size: 12, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          '© OpenStreetMap',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF5F6368),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Kontrol Zoom In & Out dan GPS di Pojok Kanan
                Positioned(
                  top: 10,
                  right: 10,
                  child: Column(
                    children: [
                      _buildMapActionButton(
                        key: const Key('btn_expand_map'),
                        icon: Icons.fullscreen_rounded,
                        tooltip: 'Perluas Peta',
                        onTap: _showExpandedMapDialog,
                      ),
                      const SizedBox(height: 6),
                      _buildMapActionButton(
                        key: const Key('btn_zoom_in'),
                        icon: Icons.add_rounded,
                        tooltip: 'Zoom In',
                        onTap: () {
                          try {
                            final nextZoom = (_mapController.camera.zoom + 1.0).clamp(3.0, 18.0);
                            _mapController.move(_mapController.camera.center, nextZoom);
                          } catch (_) {}
                        },
                      ),
                      const SizedBox(height: 6),
                      _buildMapActionButton(
                        key: const Key('btn_zoom_out'),
                        icon: Icons.remove_rounded,
                        tooltip: 'Zoom Out',
                        onTap: () {
                          try {
                            final prevZoom = (_mapController.camera.zoom - 1.0).clamp(3.0, 18.0);
                            _mapController.move(_mapController.camera.center, prevZoom);
                          } catch (_) {}
                        },
                      ),
                      const SizedBox(height: 6),
                      _buildMapActionButton(
                        key: const Key('btn_my_gps_location'),
                        icon: Icons.my_location_rounded,
                        iconColor: const Color(0xFF1A73E8),
                        tooltip: 'Lokasi Saya (GPS)',
                        onTap: _handleGpsLocation,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Komponen Search Bar Pencarian Lokasi & Dropdown Hasil
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFCBD5E1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            key: const Key('input_search_place'),
            controller: _searchCtrl,
            textInputAction: TextInputAction.search,
            onSubmitted: _performPlaceSearch,
            decoration: InputDecoration(
              hintText: 'Cari jalan, tempat, atau kota...',
              hintStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.slateText),
              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.primary),
              suffixIcon: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_searchCtrl.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() {
                                _searchResults = [];
                              });
                            },
                          ),
                        IconButton(
                          key: const Key('btn_search_place'),
                          icon: const Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.primary),
                          onPressed: () => _performPlaceSearch(_searchCtrl.text),
                        ),
                      ],
                    ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
        if (_searchResults.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            key: const Key('search_results_container'),
            constraints: const BoxConstraints(maxHeight: 200),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              elevation: 4,
              shadowColor: Colors.black.withValues(alpha: 0.15),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: _searchResults.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final result = _searchResults[index];
                  return ListTile(
                    key: Key('search_result_item_$index'),
                    dense: true,
                    leading: const Icon(Icons.place_rounded, size: 18, color: AppColors.primary),
                    title: Text(
                      result.displayName,
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _onSelectPlaceResult(result),
                  );
                },
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMapActionButton({
    required Key key,
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return Material(
      key: key,
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: iconColor ?? AppColors.darkNavy),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Quick Presets Kota Indonesia
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildQuickCityPresets() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pilih Cepat Kota di Indonesia:',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.slateText,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _presetCities.length,
            separatorBuilder: (context, index) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final city = _presetCities[index];
              final isSelected = _cityCtrl.text.toLowerCase() == (city['name'] as String).toLowerCase();
              return Container(
                key: Key('city_chip_${city['name']}'),
                child: ActionChip(
                  key: Key('chip_city_${city['name']}'),
                  label: Text(
                    city['name'] as String,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : AppColors.darkNavy,
                    ),
                  ),
                  backgroundColor: isSelected ? AppColors.primary : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  onPressed: () => _onCitySelected(city),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Komponen Input Koordinat (Latitude & Longitude)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildCoordinateDisplayCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pin_drop_outlined, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Koordinat Geografis Pin Peta',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkNavy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildCoordinateInputs(),
        ],
      ),
    );
  }

  Widget _buildManualCoordinateSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Input Koordinat Manual (Latitude & Longitude)',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkNavy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Gunakan opsi ini jika GPS perangkat tidak tersedia atau ingin menentukan koordinat presisi.',
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.slateText),
          ),
          const SizedBox(height: 12),
          _buildCoordinateInputs(),
        ],
      ),
    );
  }

  Widget _buildCoordinateInputs() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            key: const Key('input_latitude'),
            controller: _latCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            decoration: InputDecoration(
              labelText: 'Latitude',
              prefixIcon: const Icon(Icons.north_rounded, size: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Harus diisi';
              final num = double.tryParse(val.trim());
              if (num == null || num < -90 || num > 90) {
                return 'Latitude harus di antara -90 dan 90';
              }
              return null;
            },
            onChanged: (val) {
              final d = double.tryParse(val);
              if (d != null) {
                setState(() => _currentLat = d);
                try {
                  _mapController.move(LatLng(d, _currentLng), _mapController.camera.zoom);
                } catch (_) {}
              }
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextFormField(
            key: const Key('input_longitude'),
            controller: _lngCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            decoration: InputDecoration(
              labelText: 'Longitude',
              prefixIcon: const Icon(Icons.east_rounded, size: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Harus diisi';
              final num = double.tryParse(val.trim());
              if (num == null || num < -180 || num > 180) {
                return 'Longitude harus di antara -180 dan 180';
              }
              return null;
            },
            onChanged: (val) {
              final d = double.tryParse(val);
              if (d != null) {
                setState(() => _currentLng = d);
                try {
                  _mapController.move(LatLng(_currentLat, d), _mapController.camera.zoom);
                } catch (_) {}
              }
            },
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Form Field Alamat & Kota
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildAddressFormFields() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Informasi Alamat Pengiriman',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.darkNavy,
            ),
          ),
          const SizedBox(height: 12),

          // Alamat Lengkap
          TextFormField(
            key: const Key('input_address'),
            controller: _addressCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Alamat Lengkap Usaha / Outlet',
              hintText: 'Contoh: Jl. Margonda Raya No. 42, Kel. Pondok Cina',
              alignLabelWithHint: true,
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: 24),
                child: Icon(Icons.location_city_rounded, size: 18),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Alamat wajib diisi';
              }
              if (val.trim().length < 5) {
                return 'Alamat minimal 5 karakter';
              }
              return null;
            },
          ),
          if (_addressEmptyError) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'Alamat tidak boleh kosong',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.error,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Kota / Wilayah
          TextFormField(
            key: const Key('input_city'),
            controller: _cityCtrl,
            decoration: InputDecoration(
              labelText: 'Kota / Wilayah',
              hintText: 'Contoh: Jakarta Pusat',
              prefixIcon: const Icon(Icons.map_outlined, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Kota wajib diisi';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Notice Banner Izin Lokasi Ditolak
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildPermissionDeniedNotice() {
    return Container(
      key: const Key('permission_denied_banner'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Container(
        key: const Key('banner_permission_warning'),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Akses Lokasi GPS Ditolak',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF991B1B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Anda tetap dapat menentukan lokasi dengan menggeser pin peta atau beralih ke input koordinat manual.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF7F1D1D),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Tombol Simpan
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        key: const Key('btn_save_location'),
        onPressed: _isSaving ? null : _saveLocation,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 2,
        ),
        child: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Simpan Lokasi Pengiriman',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
