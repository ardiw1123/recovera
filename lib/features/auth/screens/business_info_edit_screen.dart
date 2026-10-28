import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/auth_repository.dart';
import 'location_management_screen.dart';

class BusinessInfoEditScreen extends StatefulWidget {
  const BusinessInfoEditScreen({super.key});

  @override
  State<BusinessInfoEditScreen> createState() => _BusinessInfoEditScreenState();
}

class _BusinessInfoEditScreenState extends State<BusinessInfoEditScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _companyNameController;
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;

  late final MapController _miniMapController;
  late final bool _isSeller;

  String _selectedBusinessType = 'resto';
  late double _currentLat;
  late double _currentLng;
  late List<String> _selectedCategories;
  int _maxRadiusKm = 15;
  bool _coldStorage = false;
  bool _saving = false;

  static const Map<String, String> _businessTypeOptions = {
    'resto': 'Restoran / Rumah Makan',
    'katering': 'Katering & Jasa Boga',
    'bakery': 'Bakery & Pastry',
    'warung': 'Warung Makan / Kelontong',
  };

  static const List<Map<String, String>> _availableCategories = [
    {'id': 'Beverage', 'label': 'Minuman', 'icon': '🥤'},
    {'id': 'Canned', 'label': 'Makanan Kaleng', 'icon': '🥫'},
    {'id': 'Dairy', 'label': 'Olahan Susu', 'icon': '🧀'},
    {'id': 'Flour & Grain', 'label': 'Tepung & Biji-bijian', 'icon': '🌾'},
    {'id': 'Frozen', 'label': 'Makanan Beku', 'icon': '❄️'},
    {'id': 'Oil', 'label': 'Minyak & Lemak', 'icon': '🛢️'},
  ];

  @override
  void initState() {
    super.initState();
    final profile = AuthRepository.instance.currentUserProfile;
    _isSeller = AuthRepository.instance.isSeller;

    _nameController = TextEditingController(text: profile?.name ?? '');
    _phoneController = TextEditingController(text: profile?.phone ?? '');
    _companyNameController =
        TextEditingController(text: profile?.companyName ?? '');

    final rawType = profile?.businessType?.toLowerCase() ?? 'resto';
    _selectedBusinessType =
        _businessTypeOptions.containsKey(rawType) ? rawType : 'resto';

    _addressController = TextEditingController(text: profile?.address ?? '');
    _cityController = TextEditingController(text: profile?.city ?? '');

    double lat =
        (_isSeller ? profile?.warehouseLat : profile?.baseLat) ?? -6.2088;
    if (lat.isNaN || lat < -90 || lat > 90) lat = -6.2088;
    double lng =
        (_isSeller ? profile?.warehouseLng : profile?.baseLng) ?? 106.8456;
    if (lng.isNaN || lng < -180 || lng > 180) lng = 106.8456;

    _currentLat = lat;
    _currentLng = lng;

    _selectedCategories = List<String>.from(
      profile?.prefCategories ?? const [],
    );
    _maxRadiusKm = (profile?.maxRadiusKm ?? 15).clamp(1, 25);
    _coldStorage = profile?.hasColdStorage ?? false;

    _miniMapController = MapController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _companyNameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _miniMapController.dispose();
    super.dispose();
  }

  Future<void> _openMapPicker() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LocationManagementScreen(
          initialAddress: _addressController.text.trim().isNotEmpty
              ? _addressController.text.trim()
              : null,
          initialCity: _isSeller && _cityController.text.trim().isNotEmpty
              ? _cityController.text.trim()
              : null,
          initialLat: _currentLat,
          initialLng: _currentLng,
        ),
      ),
    );

    if (result == true) {
      final profile = AuthRepository.instance.currentUserProfile;
      if (profile != null && mounted) {
        setState(() {
          if (profile.address != null && profile.address!.isNotEmpty) {
            _addressController.text = profile.address!;
          }
          if (_isSeller && profile.city != null && profile.city!.isNotEmpty) {
            _cityController.text = profile.city!;
          }
          final newLat = _isSeller ? profile.warehouseLat : profile.baseLat;
          final newLng = _isSeller ? profile.warehouseLng : profile.baseLng;
          if (newLat != null && newLng != null) {
            _currentLat = newLat;
            _currentLng = newLng;
            try {
              _miniMapController.move(LatLng(_currentLat, _currentLng), 14.0);
            } catch (_) {}
          }
        });
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Mohon lengkapi formulir yang bertanda wajib.',
            style: GoogleFonts.inter(fontSize: 12),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final auth = AuthRepository.instance;
      await auth.updateProfile(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : null,
        companyName: _isSeller ? _companyNameController.text.trim() : null,
        businessType: _isSeller ? null : _selectedBusinessType,
        address: _addressController.text.trim(),
        city: _isSeller ? _cityController.text.trim() : null,
        warehouseLat: _isSeller ? _currentLat : null,
        warehouseLng: _isSeller ? _currentLng : null,
        baseLat: _isSeller ? null : _currentLat,
        baseLng: _isSeller ? null : _currentLng,
        prefCategories: _isSeller ? null : _selectedCategories,
        maxRadiusKm: _isSeller ? null : _maxRadiusKm,
        hasColdStorage: _isSeller ? null : _coldStorage,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            key: const Key('snack_save_business_info_success'),
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Informasi bisnis berhasil diperbarui!',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Informasi bisnis gagal disimpan: $e',
              style: GoogleFonts.inter(fontSize: 12),
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _required(String? value, {String fieldName = 'Field ini'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName wajib diisi';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 8) {
      return 'Nomor telepon minimal 8 digit';
    }
    return null;
  }

  InputDecoration _inputDecoration({
    required String labelText,
    String? hintText,
    String? helperText,
    Widget? prefixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.slateText,
      ),
      hintText: hintText,
      hintStyle: GoogleFonts.inter(
        fontSize: 13,
        color: const Color(0xFF94A3B8),
      ),
      helperText: helperText,
      helperMaxLines: 2,
      helperStyle: GoogleFonts.inter(
        fontSize: 11,
        color: AppColors.slateText,
      ),
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkNavy,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.slateText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(color: AppColors.border, height: 1),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniMapPreview() {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _miniMapController,
              options: MapOptions(
                initialCenter: LatLng(_currentLat, _currentLng),
                initialZoom: 14.0,
                minZoom: 3.0,
                maxZoom: 18.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
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
                      width: 44,
                      height: 44,
                      alignment: Alignment.topCenter,
                      child: const Icon(
                        Icons.location_on_rounded,
                        size: 40,
                        color: Color(0xFFEA4335),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _openMapPicker,
                  child: Container(),
                ),
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.pin_drop_rounded,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_currentLat.toStringAsFixed(4)}, ${_currentLng.toStringAsFixed(4)}',
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
            Positioned(
              bottom: 10,
              right: 10,
              child: ElevatedButton.icon(
                key: const Key('btn_open_map_picker'),
                icon: const Icon(Icons.map_rounded, size: 16),
                label: Text(
                  'Atur di Peta',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 2,
                ),
                onPressed: _openMapPicker,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoordinatesDisplay() {
    return Container(
      key: const Key('display_coordinates'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.my_location_rounded,
              size: 16,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Koordinat Geografis (Otomatis dari Peta)',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.slateText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Lat: ${_currentLat.toStringAsFixed(6)}, Lng: ${_currentLng.toStringAsFixed(6)}',
                  style: GoogleFonts.robotoMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkNavy,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF6EE7B7)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 12,
                  color: Color(0xFF10B981),
                ),
                const SizedBox(width: 4),
                Text(
                  'Tersinkron',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF047857),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuyerPreferencesCard() {
    return _buildSectionCard(
      icon: Icons.tune_rounded,
      title: 'Preferensi Rekomendasi & Pengadaan',
      subtitle:
          'Membantu AI Recovera memprioritaskan lot near-expiry yang sesuai kebutuhan usaha Anda (bobot 30%)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Kategori Produk Prioritas',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkNavy,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_selectedCategories.length} Dipilih',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableCategories.map((cat) {
              final id = cat['id']!;
              final label = cat['label']!;
              final icon = cat['icon']!;
              final isSelected = _selectedCategories.contains(id);

              return FilterChip(
                key: Key('chip_category_$id'),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(icon, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? AppColors.primaryDark
                            : AppColors.darkNavy,
                      ),
                    ),
                  ],
                ),
                selected: isSelected,
                showCheckmark: false,
                selectedColor: AppColors.primary.withValues(alpha: 0.12),
                backgroundColor: const Color(0xFFF8FAFC),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: isSelected ? 1.5 : 1.0,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedCategories.add(id);
                    } else {
                      _selectedCategories.remove(id);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: AppColors.border, height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Radius Penjemputan / Pengantaran',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkNavy,
                      ),
                    ),
                    Text(
                      'Batas jarak pencarian lot seller dari lokasi Anda',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.slateText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_maxRadiusKm km',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: const Color(0xFFE2E8F0),
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withValues(alpha: 0.15),
              trackHeight: 6,
            ),
            child: Slider(
              key: const Key('slider_radius'),
              value: _maxRadiusKm.toDouble().clamp(1.0, 25.0),
              min: 1.0,
              max: 25.0,
              divisions: 24,
              label: '$_maxRadiusKm km',
              onChanged: (val) {
                setState(() => _maxRadiusKm = val.round());
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: AppColors.border, height: 1),
          ),
          SwitchListTile(
            key: const Key('switch_cold_storage'),
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Fasilitas Cold Storage / Chiller',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.darkNavy,
              ),
            ),
            subtitle: Text(
              'Aktifkan jika memiliki freezer/kulkas untuk menampung produk susu & makanan beku',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.slateText,
              ),
            ),
            value: _coldStorage,
            activeTrackColor: AppColors.primary,
            onChanged: (value) => setState(() => _coldStorage = value),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        key: const Key('btn_save_business_info'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 2,
        ),
        onPressed: _saving ? null : _save,
        child: _saving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.save_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Simpan Perubahan',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvasBg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Informasi Bisnis',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              _isSeller
                  ? 'Kelola Profil Distributor & Gudang'
                  : 'Kelola Profil Usaha & Pengadaan',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
        leading: IconButton(
          key: const Key('btn_back_business_info'),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 18,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: _buildSaveButton(),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            physics: const BouncingScrollPhysics(),
            children: [
              // ── 1. Identitas Penanggung Jawab ──
              _buildSectionCard(
                icon: Icons.person_rounded,
                title: 'Identitas Penanggung Jawab (PIC)',
                subtitle:
                    'Kontak operasional untuk konfirmasi pesanan & serah terima',
                child: Column(
                  children: [
                    TextFormField(
                      key: const Key('input_pic_name'),
                      controller: _nameController,
                      validator: (v) => _required(v, fieldName: 'Nama PIC'),
                      decoration: _inputDecoration(
                        labelText: 'Nama PIC / Penanggung Jawab',
                        hintText: 'Nama lengkap penanggung jawab',
                        prefixIcon: const Icon(
                          Icons.badge_outlined,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      key: const Key('input_phone'),
                      controller: _phoneController,
                      validator: _validatePhone,
                      keyboardType: TextInputType.phone,
                      decoration: _inputDecoration(
                        labelText: 'Nomor Telepon / WhatsApp',
                        hintText: 'Contoh: 081234567890',
                        helperText:
                            'Nomor aktif yang dapat dihubungi oleh kurir dan mitra',
                        prefixIcon: const Icon(
                          Icons.phone_outlined,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── 2. Profil Usaha ──
              _buildSectionCard(
                icon: Icons.storefront_rounded,
                title: _isSeller ? 'Profil Distributor' : 'Profil Usaha',
                subtitle: _isSeller
                    ? 'Identitas badan usaha penyedia pasokan batch lot'
                    : 'Kategori jenis unit usaha kuliner atau ritel',
                child: Column(
                  children: [
                    if (_isSeller)
                      TextFormField(
                        key: const Key('input_company_name'),
                        controller: _companyNameController,
                        validator: (v) =>
                            _required(v, fieldName: 'Nama perusahaan'),
                        decoration: _inputDecoration(
                          labelText: 'Nama Perusahaan / Distributor',
                          hintText: 'Contoh: PT Sumber Pangan Sejahtera',
                          prefixIcon: const Icon(
                            Icons.apartment_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        key: const Key('dropdown_business_type'),
                        initialValue: _selectedBusinessType,
                        decoration: _inputDecoration(
                          labelText: 'Jenis Bisnis Kuliner',
                          helperText:
                              'Digunakan AI untuk matching lot bahan baku yang relevan',
                          prefixIcon: const Icon(
                            Icons.category_outlined,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        items: _businessTypeOptions.entries.map((entry) {
                          return DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(
                              entry.value,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.darkNavy,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedBusinessType = val);
                          }
                        },
                      ),
                  ],
                ),
              ),

              // ── 3. Lokasi Operasional ──
              _buildSectionCard(
                icon: Icons.location_on_rounded,
                title: _isSeller
                    ? 'Lokasi Gudang & Titik Pickup'
                    : 'Lokasi Usaha & Pengiriman',
                subtitle:
                    'Titik koordinat dan alamat operasional untuk rute logistik',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMiniMapPreview(),
                    const SizedBox(height: 14),
                    TextFormField(
                      key: const Key('input_address'),
                      controller: _addressController,
                      validator: (v) =>
                          _required(v, fieldName: 'Alamat operasional'),
                      maxLines: 2,
                      decoration: _inputDecoration(
                        labelText:
                            _isSeller ? 'Alamat Gudang' : 'Alamat Usaha',
                        hintText:
                            'Nama jalan, nomor bangunan, RT/RW, atau patokan',
                        helperText:
                            'Otomatis terisi dari titik peta, dapat disesuaikan',
                        prefixIcon: const Icon(
                          Icons.place_outlined,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                    ),
                    if (_isSeller) ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        key: const Key('input_city'),
                        controller: _cityController,
                        validator: (v) =>
                            _required(v, fieldName: 'Kota gudang'),
                        decoration: _inputDecoration(
                          labelText: 'Kota Operasional',
                          hintText: 'Contoh: Jakarta Pusat, Depok, Surabaya',
                          helperText:
                              'Otomatis terisi dari hasil reverse geocoding peta',
                          prefixIcon: const Icon(
                            Icons.location_city_outlined,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    _buildCoordinatesDisplay(),
                  ],
                ),
              ),

              // ── 4. Preferensi Operasional (Buyer Only) ──
              if (!_isSeller) _buildBuyerPreferencesCard(),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
