import 'dart:convert';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../core/network/api_client.dart';
import '../../features/home/models/product_model.dart';
import '../database/app_database.dart';
import '../database/database_constants.dart';
import '../models/chat_message_model.dart';
import 'auth_repository.dart';

class ChatRepository {
  final ApiClient _apiClient;
  final AppDatabase _database;

  // Cache in-memory untuk Web / fallback jika SQLite tidak tersedia
  static final Map<int, List<ChatMessageModel>> _inMemoryStore = {};

  ChatRepository({
    ApiClient? apiClient,
    AppDatabase? database,
  })  : _apiClient = apiClient ?? ApiClient(),
        _database = database ?? AppDatabase.instance;

  /// Mengambil semua riwayat obrolan user tertentu dari SQLite lokal atau cache in-memory
  Future<List<ChatMessageModel>> getMessages(int userId) async {
    if (kIsWeb) {
      return List<ChatMessageModel>.from(_inMemoryStore[userId] ?? []);
    }

    try {
      final db = await _database.database;
      final maps = await db.query(
        DatabaseConstants.tableChatMessages,
        where: '${DatabaseConstants.colChatUserId} = ?',
        whereArgs: [userId],
        orderBy: '${DatabaseConstants.colChatCreatedAt} ASC',
      );

      final list = maps.map((m) => ChatMessageModel.fromMap(m)).toList();
      _inMemoryStore[userId] = list;
      return list;
    } catch (_) {
      return List<ChatMessageModel>.from(_inMemoryStore[userId] ?? []);
    }
  }

  /// Menyimpan satu pesan ke SQLite lokal dan in-memory cache
  Future<ChatMessageModel> saveMessage(ChatMessageModel message) async {
    // Bersihkan asteriks sebelum disimpan
    final cleanedMsg = ChatMessageModel(
      id: message.id,
      userId: message.userId,
      role: message.role,
      message: message.message.replaceAll('**', '').replaceAll('*', ''),
      intent: message.intent,
      richCardJson: message.richCardJson,
      createdAt: message.createdAt,
    );

    _inMemoryStore.putIfAbsent(cleanedMsg.userId, () => []);
    _inMemoryStore[cleanedMsg.userId]!.add(cleanedMsg);

    if (kIsWeb) {
      return cleanedMsg;
    }

    try {
      final db = await _database.database;
      final id = await db.insert(
        DatabaseConstants.tableChatMessages,
        cleanedMsg.toMap(),
      );

      return ChatMessageModel(
        id: id,
        userId: cleanedMsg.userId,
        role: cleanedMsg.role,
        message: cleanedMsg.message,
        intent: cleanedMsg.intent,
        richCardJson: cleanedMsg.richCardJson,
        createdAt: cleanedMsg.createdAt,
      );
    } catch (_) {
      return cleanedMsg;
    }
  }

  /// Menghapus semua riwayat obrolan user tertentu
  Future<void> clearHistory(int userId) async {
    _inMemoryStore[userId]?.clear();

    if (kIsWeb) return;

    try {
      final db = await _database.database;
      await db.delete(
        DatabaseConstants.tableChatMessages,
        where: '${DatabaseConstants.colChatUserId} = ?',
        whereArgs: [userId],
      );
    } catch (_) {}
  }

  /// Mengirim pesan ke backend AI (Google Gemini + model matching)
  Future<ChatMessageModel> sendMessage({
    required int userId,
    required String message,
    required List<ChatMessageModel> currentHistory,
  }) async {
    // 1. Simpan pesan user
    await saveMessage(
      ChatMessageModel(
        userId: userId,
        role: 'user',
        message: message,
      ),
    );

    // 2. Format history
    final historyPayload = currentHistory
        .take(4)
        .map((m) => {
              'role': m.role,
              'content': m.message,
            })
        .toList();

    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/ai/chat',
        data: {
          'message': message,
          'history': historyPayload,
        },
        options: Options(
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );

      final data = response.data?['data'] as Map<String, dynamic>? ?? {};
      var replyText = data['reply'] as String? ?? 'Maaf, terjadi kendala saat memproses jawaban.';
      replyText = replyText.replaceAll('**', '').replaceAll('*', '');
      final intent = data['intent'] as String? ?? 'general_faq';
      final richCardMap = data['rich_card'] as Map<String, dynamic>?;

      final assistantMsg = await saveMessage(
        ChatMessageModel(
          userId: userId,
          role: 'assistant',
          message: replyText,
          intent: intent,
          richCardJson: richCardMap != null ? jsonEncode(richCardMap) : null,
        ),
      );

      return assistantMsg;
    } catch (e) {
      // 3. Fallback cerdas terhubung data katalog produk Recovera
      final localReply = _generateSmartLocalReply(userId, message);
      final savedReply = await saveMessage(localReply);
      return savedReply;
    }
  }

  // ── Helper Jarak & Format Rupiah ─────────────────────────────────────────

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) *
            math.cos(lat2 * p) *
            (1 - math.cos((lon2 - lon1) * p)) /
            2;
    return 12742 * math.asin(math.sqrt(a));
  }

  String _formatRp(num val) {
    final s = val.toInt().toString();
    final chars = s.split('').reversed.toList();
    final parts = <String>[];
    for (var i = 0; i < chars.length; i += 3) {
      parts.add(chars.sublist(i, i + 3 > chars.length ? chars.length : i + 3).join());
    }
    return 'Rp ${parts.join('.').split('').reversed.join()}';
  }

  /// Mesin respons cerdas terhubung ke data katalog produk & lokasi user
  ChatMessageModel _generateSmartLocalReply(int userId, String message) {
    final q = message.toLowerCase();

    // Dapatkan profil & lokasi pengguna
    final profile = AuthRepository.instance.currentUserProfile;
    final userLat = profile?.baseLat ?? profile?.warehouseLat ?? -6.2088;
    final userLng = profile?.baseLng ?? profile?.warehouseLng ?? 106.8456;
    final userCity = profile?.city ?? 'Jakarta';

    // ── 1. Pertanyaan Produk Termurah ──────────────────────────────────────
    if (q.contains('termurah') ||
        q.contains('paling murah') ||
        q.contains('harga terendah') ||
        q.contains('murah')) {
      final sortedByPrice = List<Listing>.from(dummyListings)
        ..sort((a, b) => a.startPrice.compareTo(b.startPrice));

      final topProducts = sortedByPrice.take(3).toList();
      final sb = StringBuffer();
      sb.writeln('Tentu! Berikut 3 produk lelang dengan harga pembuka termurah yang sedang aktif saat ini:\n');

      for (var i = 0; i < topProducts.length; i++) {
        final p = topProducts[i];
        final diskon = ((p.normalPrice - p.startPrice) / p.normalPrice * 100).round();
        sb.writeln('${i + 1}. ${p.productName} (${p.brand ?? 'Reguler'})');
        sb.writeln('   Penjual: ${p.companyName} - ${p.city}');
        sb.writeln('   Harga lelang: ${_formatRp(p.startPrice)} (Diskon $diskon% dari ${_formatRp(p.normalPrice)})');
        sb.writeln('   Sisa stok: ${p.qty} ${p.defaultUnit} | Kedaluwarsa: ${p.effectiveDaysToExpiry} hari lagi\n');
      }

      sb.write('Kamu bisa langsung beli produk-produk ini di halaman Beranda sebelum kuota habis atau diambil pembeli lain.');

      return ChatMessageModel(
        userId: userId,
        role: 'assistant',
        message: sb.toString().trim(),
        intent: 'product_catalog',
      );
    }

    // ── 2. Pertanyaan Produk Terdekat dari Jangkauan ────────────────────────
    if (q.contains('terdekat') ||
        q.contains('paling dekat') ||
        q.contains('jangkauan') ||
        q.contains('radius') ||
        q.contains('sekitar saya') ||
        q.contains('dekat')) {
      // Hitung jarak ke setiap listing
      final listingsWithDist = dummyListings.map((l) {
        final dist = _haversineKm(userLat, userLng, l.warehouseLat, l.warehouseLng);
        return {'listing': l, 'dist': dist};
      }).toList()
        ..sort((a, b) => (a['dist'] as double).compareTo(b['dist'] as double));

      final nearest = listingsWithDist.take(3).toList();
      final sb = StringBuffer();
      sb.writeln('Berdasarkan jangkauan lokasi kamu (${userCity}), ini 3 produk lelang yang jaraknya paling dekat:\n');

      for (var i = 0; i < nearest.length; i++) {
        final p = nearest[i]['listing'] as Listing;
        final d = (nearest[i]['dist'] as double).toStringAsFixed(1);
        final diskon = ((p.normalPrice - p.startPrice) / p.normalPrice * 100).round();
        sb.writeln('${i + 1}. ${p.productName}');
        sb.writeln('   Jarak: sekitar $d km dari lokasimu (Gudang: ${p.city})');
        sb.writeln('   Harga lelang: ${_formatRp(p.startPrice)} (Diskon $diskon%)');
        sb.writeln('   Penyimpanan: ${p.storageType == 'chilled' ? 'Rantai Dingin (Chilled)' : p.storageType == 'frozen' ? 'Rantai Dingin (Frozen)' : 'Suhu Ruang (Ambient)'}\n');
      }

      sb.write('Karena lokasinya dekat, pengiriman jadi jauh lebih cepat, hemat ongkir, dan kualitas pangan tetap terjaga.');

      return ChatMessageModel(
        userId: userId,
        role: 'assistant',
        message: sb.toString().trim(),
        intent: 'product_catalog',
      );
    }

    // ── 3. Pertanyaan Produk Spesifik / Kategori ────────────────────────────
    final matchedListings = dummyListings.where((l) {
      final name = l.productName.toLowerCase();
      final cat = l.category.label.toLowerCase();
      final brand = (l.brand ?? '').toLowerCase();
      return (q.contains('susu') && name.contains('susu')) ||
          (q.contains('keju') && name.contains('keju')) ||
          (q.contains('minyak') && name.contains('minyak')) ||
          (q.contains('daging') && (name.contains('daging') || cat.contains('frozen'))) ||
          (q.contains('tepung') && (name.contains('tepung') || cat.contains('flour'))) ||
          (q.contains('frozen') && (cat.contains('frozen') || l.storageType == 'frozen')) ||
          (q.contains('dairy') && (cat.contains('dairy') || l.storageType == 'chilled')) ||
          (q.contains('kaleng') && cat.contains('canned'));
    }).toList();

    if (matchedListings.isNotEmpty) {
      final sb = StringBuffer();
      sb.writeln('Tersedia! Berikut produk lelang yang sesuai dengan pencarianmu:\n');

      for (var i = 0; i < math.min(3, matchedListings.length); i++) {
        final p = matchedListings[i];
        final diskon = ((p.normalPrice - p.startPrice) / p.normalPrice * 100).round();
        sb.writeln('${i + 1}. ${p.productName}');
        sb.writeln('   Distributor: ${p.companyName} (${p.city})');
        sb.writeln('   Harga lelang: ${_formatRp(p.startPrice)} (Diskon $diskon% dari ${_formatRp(p.normalPrice)})');
        sb.writeln('   Stok: ${p.qty} ${p.defaultUnit} | Kedaluwarsa: ${p.effectiveDaysToExpiry} hari lagi\n');
      }

      sb.write('Semua produk di atas siap dikirim dan telah lolos seleksi kualitas Recovera.');

      return ChatMessageModel(
        userId: userId,
        role: 'assistant',
        message: sb.toString().trim(),
        intent: 'product_catalog',
      );
    }

    // ── 4. Skenario: Simulasi Peluang Produk (Seller) ────────────────────────
    final isSimulation = q.contains('jual') ||
        q.contains('peluang') ||
        q.contains('tertarik') ||
        q.contains('cocok') ||
        q.contains('harga segini');

    if (isSimulation) {
      final richCardData = {
        'type': 'product_simulation',
        'data': {
          'category': q.contains('susu') ? 'Dairy' : 'General',
          'qty': 50,
          'normal_price': 210000.0,
          'suggested_start_price': 147000.0,
          'suggested_discount_pct': 30.0,
          'matched_buyers_count': 6,
          'average_distance_km': 6.8,
          'disclaimer':
              'Hasil ini merupakan estimasi potensi kecocokan kebutuhan pembeli terdekat, bukan kepastian transaksi.',
        },
        'action': {
          'label': 'Terapkan ke Listing Baru',
          'route': '/seller/tambah-stok',
          'params': {
            'category': 'Dairy',
            'normal_price': 210000.0,
            'start_price': 147000.0,
            'qty': 50,
          },
        },
      };

      return ChatMessageModel(
        userId: userId,
        role: 'assistant',
        message:
            'Berdasarkan analisis model Recovera:\n\n'
            '1. Potensi Pembeli: Ditemukan sekitar 6 calon pembeli di sekitar gudang Anda (radius rata-rata ~6.8 km) yang memiliki kebutuhan dan fasilitas penyimpanan sesuai.\n'
            '2. Rekomendasi Diskon Awal: Disarankan diskon awal 30% (harga lelang pembuka Rp 147.000) agar cepat menarik perhatian pada jam-jam pertama lelang.\n\n'
            'Hasil ini adalah estimasi potensi kecocokan pembeli di sistem kami.',
        intent: 'product_opportunity',
        richCardJson: jsonEncode(richCardData),
      );
    }

    // ── 5. Rantai Dingin (Cold Chain) ──────────────────────────────────────
    if (q.contains('rantai dingin') || q.contains('cold chain') || q.contains('pendingin') || q.contains('suhu')) {
      return ChatMessageModel(
        userId: userId,
        role: 'assistant',
        message:
            'Di Recovera, produk pangan dingin (Chilled) dan beku (Frozen) dilindungi oleh protokol rantai dingin yang ketat:\n\n'
            '1. Verifikasi Fasilitas: Pembeli dan penjual wajib memiliki sertifikasi unit pendingin yang valid di profil bisnis mereka.\n'
            '2. Filter Pencocokan Otomatis: Produk dingin hanya akan ditawarkan kepada pembeli yang terbukti memiliki fasilitas cold storage.\n'
            '3. Kontrol Suhu: Saat pengiriman dan serah terima, suhu diukur agar tetap stabil (0 hingga 4 derajat Celcius untuk chilled, dan minus 18 derajat Celcius untuk frozen).',
        intent: 'general_faq',
      );
    }

    // ── 6. Lelang Dinamis (Dutch Auction) ───────────────────────────────────
    if (q.contains('lelang') || q.contains('dutch') || q.contains('turun')) {
      return ChatMessageModel(
        userId: userId,
        role: 'assistant',
        message:
            'Lelang di Recovera memakai sistem Dutch Auction (Lelang Turun):\n\n'
            '1. Harga Pembuka: Produk dibuka dengan diskon awal tertentu yang ditentukan penjual.\n'
            '2. Penurunan Berkala: Harga turun otomatis berkala (misal 2.5% per jam) seiring berjalannya waktu.\n'
            '3. Siapa Cepat Dia Dapat: Pembeli pertama yang mengonfirmasi harga saat itu langsung memenangkan produk tanpa perlu saling menawar.\n'
            '4. Batas Aman: Harga tidak akan pernah turun melewati harga batas bawah (min_price) yang ditentukan penjual.',
        intent: 'general_faq',
      );
    }

    // ── 7. Donasi SOS & Food Waste ──────────────────────────────────────────
    if (q.contains('donasi') || q.contains('expired') || q.contains('kedaluwarsa') || q.contains('food waste')) {
      return ChatMessageModel(
        userId: userId,
        role: 'assistant',
        message:
            'Untuk mencegah pembuangan makanan (food waste), Recovera memiliki fitur Donasi Otomatis (SOS Diversion):\n\n'
            'Jika produk surplus pangan memiliki sisa waktu simpan kurang dari 15 hari dan belum terjual di lelang, sistem otomatis membuka jalur pengalihan donasi ke bank pangan sosial terdaftar agar makanan tetap tersalurkan kepada yang membutuhkan.',
        intent: 'general_faq',
      );
    }

    // ── 8. ESG & Jejak Karbon ──────────────────────────────────────────────
    if (q.contains('esg') || q.contains('karbon') || q.contains('sertifikat')) {
      return ChatMessageModel(
        userId: userId,
        role: 'assistant',
        message:
            'Setiap kilogram pangan surplus yang terselamatkan dari tempat pembuangan akhir dihitung pengurangan emisi karbonnya (kg CO2e).\n\n'
            'Data transaksi ini diverifikasi di jaringan blockchain dan dapat diunduh langsung sebagai Sertifikat Dampak ESG resmi untuk laporan keberlanjutan perusahaan Anda.',
        intent: 'general_faq',
      );
    }

    // ── 9. Respons Ramah & Luwes Default ───────────────────────────────────
    return ChatMessageModel(
      userId: userId,
      role: 'assistant',
      message:
          'Halo! Saya Asisten Recovera. Saya terhubung langsung dengan katalog dan database lelang kami.\n\n'
          'Anda bisa tanyakan hal seperti:\n'
          '• Produk apa saja yang harganya paling murah saat ini?\n'
          '• Produk apa yang lokasinya paling dekat dengan saya?\n'
          '• Ketersediaan produk tertentu (misal: susu, minyak, keju)\n'
          '• Simulasi peluang produk lelang baru (khusus penjual)\n'
          '• Cara kerja lelang dinamis, rantai dingin, dan sertifikat ESG\n\n'
          'Ada yang ingin Anda cari atau tanyakan?',
      intent: 'general_faq',
    );
  }
}

