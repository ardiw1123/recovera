import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/esg_certificate_model.dart';
import '../repositories/seller_repository.dart';
import 'esg_certificate_detail_screen.dart';

class EsgCertificateListScreen extends StatefulWidget {
  const EsgCertificateListScreen({super.key, this.sellerId});

  final int? sellerId;

  @override
  State<EsgCertificateListScreen> createState() =>
      _EsgCertificateListScreenState();
}

class _EsgCertificateListScreenState extends State<EsgCertificateListScreen> {
  final _repository = SellerRepository.instance;
  Future<List<EsgCertificateListItem>>? _certificatesFuture;

  @override
  void initState() {
    super.initState();
    _loadCertificates();
  }

  void _loadCertificates() {
    setState(() {
      _certificatesFuture = widget.sellerId == null
          ? _repository.fetchMyCertificates()
          : _repository.fetchSellerCertificates(widget.sellerId!);
    });
  }

  Color _getGradeColor(String grade) {
    switch (grade.toUpperCase()) {
      case 'A':
        return Colors.green.shade700;
      case 'B':
        return Colors.amber.shade800;
      case 'C':
      default:
        return Colors.deepOrange.shade800;
    }
  }

  String _getGradeLabel(String grade) {
    switch (grade.toUpperCase()) {
      case 'A':
        return 'Grade A (Food Bank)';
      case 'B':
        return 'Grade B (Pakan Ternak)';
      case 'C':
      default:
        return 'Grade C (Kompos)';
    }
  }

  /// Simulasi pengujian (dev-only): membuat listing uji near-expiry lalu
  /// menjalankan alur diversion & penerbitan sertifikat ESG yang asli.
  Future<void> _runDiversionTest() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Jalankan Pengujian?'),
        content: const Text(
          'Sistem akan membuat produk uji "[UJI] Susu UHT 1L" (kedaluwarsa 5 hari), '
          'mengalihkannya ke jalur donasi (diversion), dan menerbitkan sertifikat ESG '
          'yang tercatat di BOT Chain Testnet.\n\n'
          'Klik berulang tidak membuat duplikat sertifikat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Jalankan'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const Dialog(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Memproses diversion & mencatat ke BOT Chain...',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final result = await _repository.runEsgDiversionTest();
      if (!mounted) return;
      Navigator.of(context).pop(); // tutup dialog loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.isRecorded
                ? 'Sertifikat ${result.certificateNo} diterbitkan & tercatat di blockchain ✅'
                : 'Sertifikat ${result.certificateNo} diterbitkan, menunggu pencatatan blockchain ⏳',
          ),
          backgroundColor: result.isRecorded
              ? Colors.green.shade700
              : Colors.amber.shade800,
        ),
      );
      _loadCertificates();
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // tutup dialog loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pengujian gagal: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sertifikat ESG Blockchain'),
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.science_outlined),
              onPressed: _runDiversionTest,
              tooltip: 'Simulasi Pengujian Diversion',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCertificates,
            tooltip: 'Segarkan',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadCertificates(),
        child: FutureBuilder<List<EsgCertificateListItem>>(
          future: _certificatesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Gagal memuat sertifikat: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadCertificates,
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final items = snapshot.data ?? [];

            if (items.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.eco_outlined,
                          size: 64,
                          color: Colors.green.shade700,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Belum Ada Sertifikat ESG',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Stok produk lelang yang mendekati masa expired (< 15 hari) akan dialihkan ke jalur donasi offtaker dan diterbitkan sertifikat ESG yang tercatat di BOT Chain Testnet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          height: 1.4,
                        ),
                      ),
                      if (kDebugMode) ...[
                        const SizedBox(height: 20),
                        OutlinedButton.icon(
                          onPressed: _runDiversionTest,
                          icon: const Icon(Icons.science_outlined, size: 18),
                          label: const Text('Jalankan Pengujian (Simulasi)'),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isRecorded =
                    item.blockchainStatus.toLowerCase() == 'tercatat' ||
                    item.certificateTxHash != null;
                final gradeColor = _getGradeColor(item.grade);

                return Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  elevation: 1.5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isRecorded
                          ? Colors.green.shade200
                          : Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              EsgCertificateDetailScreen(donationId: item.id),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.certificateNo,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.grey.shade800,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isRecorded
                                      ? Colors.green.shade50
                                      : Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isRecorded
                                        ? Colors.green.shade400
                                        : Colors.amber.shade400,
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isRecorded
                                          ? Icons.verified
                                          : Icons.hourglass_top,
                                      size: 13,
                                      color: isRecorded
                                          ? Colors.green.shade800
                                          : Colors.amber.shade900,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isRecorded ? 'Tercatat ✅' : 'Menunggu ⏳',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isRecorded
                                            ? Colors.green.shade900
                                            : Colors.amber.shade900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            item.productName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: gradeColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _getGradeLabel(item.grade),
                                  style: TextStyle(
                                    color: gradeColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '• ${item.qtyDiverted} unit',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.park,
                                    size: 16,
                                    color: Colors.green.shade700,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${item.carbonSavedKg.toStringAsFixed(1)} kg CO2e terselamatkan',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green.shade800,
                                    ),
                                  ),
                                ],
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: Colors.grey.shade400,
                                size: 20,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
