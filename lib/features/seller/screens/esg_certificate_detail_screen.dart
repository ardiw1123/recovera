import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/esg_certificate_model.dart';
import '../repositories/seller_repository.dart';

class EsgCertificateDetailScreen extends StatefulWidget {
  final int donationId;

  const EsgCertificateDetailScreen({
    super.key,
    required this.donationId,
  });

  @override
  State<EsgCertificateDetailScreen> createState() =>
      _EsgCertificateDetailScreenState();
}

class _EsgCertificateDetailScreenState
    extends State<EsgCertificateDetailScreen> {
  final _repository = SellerRepository.instance;
  Future<EsgCertificateDetail>? _detailFuture;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  void _loadDetail() {
    setState(() {
      _detailFuture = _repository.fetchCertificateDetail(widget.donationId);
    });
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label berhasil disalin ke clipboard'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openExplorer(String? url) async {
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tautan block explorer belum tersedia'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final uri = Uri.parse(url);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuka explorer: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _verifyOnChain(String txHash) async {
    setState(() => _isVerifying = true);
    try {
      final result = await _repository.verifyBlockchain(txHash);
      if (!mounted) return;
      _showVerificationModal(result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memverifikasi on-chain: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  void _showVerificationModal(BlockchainVerificationResult result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isSuccess = result.verified;
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).padding.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isSuccess ? Icons.verified : Icons.warning_amber_rounded,
                    color: isSuccess ? Colors.green.shade700 : Colors.red,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isSuccess
                          ? 'Verifikasi Blockchain Berhasil'
                          : 'Verifikasi Blockchain Gagal',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              _buildVerifyRow('Status', result.status),
              _buildVerifyRow('Jaringan', result.network),
              if (result.blockNumber != null)
                _buildVerifyRow('Nomor Blok', '#${result.blockNumber}'),
              _buildVerifyRow(
                'Alamat Kontrak',
                result.contractAddress,
                onCopy: () => _copyToClipboard(
                  result.contractAddress,
                  'Alamat Kontrak',
                ),
              ),
              if (result.certificateHashOnChain != null)
                _buildVerifyRow(
                  'Hash Data On-Chain',
                  result.certificateHashOnChain!,
                  onCopy: () => _copyToClipboard(
                    result.certificateHashOnChain!,
                    'Hash On-Chain',
                  ),
                ),
              if (result.verifiedAt != null)
                _buildVerifyRow('Waktu Verifikasi', result.verifiedAt!),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _openExplorer(result.blockExplorerUrl);
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Buka di Block Explorer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVerifyRow(String label, String value, {VoidCallback? onCopy}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (onCopy != null)
            InkWell(
              onTap: onCopy,
              child: const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.copy, size: 16, color: Colors.blue),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Sertifikat ESG'),
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDetail,
            tooltip: 'Muat ulang',
          ),
        ],
      ),
      body: FutureBuilder<EsgCertificateDetail>(
        future: _detailFuture,
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
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(
                      'Gagal memuat sertifikat: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadDetail,
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            );
          }

          final detail = snapshot.data!;
          final isRecorded = detail.blockchainStatus.toLowerCase() == 'tercatat' ||
              detail.certificateTxHash != null;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Header Sertifikat Resmi
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.green.shade200, width: 1.5),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: [Colors.green.shade50, Colors.white],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.eco, color: Colors.green.shade800, size: 30),
                            const SizedBox(width: 8),
                            Text(
                              'SERTIFIKAT ESG RESMI',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: Colors.green.shade900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Pencatatan Jejak Pengalihan Pangan Surplus',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                detail.certificateNo,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () => _copyToClipboard(
                                  detail.certificateNo,
                                  'Nomor Sertifikat',
                                ),
                                child: const Icon(Icons.copy,
                                    size: 18, color: Colors.blue),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isRecorded
                                ? Colors.green.shade100
                                : Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isRecorded
                                    ? Icons.check_circle
                                    : Icons.hourglass_top,
                                size: 16,
                                color: isRecorded
                                    ? Colors.green.shade800
                                    : Colors.amber.shade900,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isRecorded
                                    ? 'Tercatat di BOT Chain Testnet'
                                    : 'Menunggu Sinkronisasi Blockchain',
                                style: TextStyle(
                                  fontSize: 12,
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
                  ),
                ),

                const SizedBox(height: 16),

                // 2. Info Produk & Grade Kelayakan
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Rincian Donasi Pangan',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Divider(height: 20),
                        _buildDetailItem(
                          icon: Icons.inventory_2_outlined,
                          label: 'Nama Produk',
                          value: detail.productName,
                        ),
                        _buildDetailItem(
                          icon: Icons.scale_outlined,
                          label: 'Jumlah Dialihkan',
                          value: '${detail.qtyDiverted} unit',
                        ),
                        _buildDetailItem(
                          icon: Icons.handshake_outlined,
                          label: 'Mitra Penerima',
                          value: '${detail.offtakerName} (${detail.offtakerType})',
                        ),
                        const SizedBox(height: 10),
                        _buildGradeCard(detail.grade),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 3. Dampak Lingkungan (Carbon Saved)
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  color: Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade800,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.park,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Estimasi Penyelamatan Emisi Karbon',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${detail.carbonSavedKg.toStringAsFixed(1)} kg CO2e',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.green.shade900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 4. Nilai Pangan Terselamatkan (4 Mata Uang)
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Nilai Valuasi Pangan Terselamatkan',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Dikonversi secara dinamis dari nilai rupiah',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const Divider(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _buildCurrencyTile(
                                'IDR',
                                'Rp ${_formatNumber(detail.monetaryValue.idr)}',
                                Colors.blue.shade700,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildCurrencyTile(
                                'USD',
                                '\$ ${detail.monetaryValue.usd.toStringAsFixed(2)}',
                                Colors.teal.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _buildCurrencyTile(
                                'EUR',
                                '€ ${detail.monetaryValue.eur.toStringAsFixed(2)}',
                                Colors.indigo.shade700,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildCurrencyTile(
                                'GBP',
                                '£ ${detail.monetaryValue.gbp.toStringAsFixed(2)}',
                                Colors.purple.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 5. Waktu Penerbitan (London & WIB)
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Waktu Resmi Penerbitan',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Divider(height: 20),
                        _buildDetailItem(
                          icon: Icons.access_time_filled,
                          label: 'Waktu Indonesia Barat (WIB)',
                          value: detail.issuedAtWib,
                        ),
                        _buildDetailItem(
                          icon: Icons.public,
                          label: 'Waktu Standar London (GMT/BST)',
                          value: detail.issuedAtLondon,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 6. Rincian On-Chain & Aksi Verifikasi
                if (isRecorded && detail.certificateTxHash != null) ...[
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Informasi Blockchain BOT Chain',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Divider(height: 20),
                          if (detail.blockNumber != null)
                            _buildDetailItem(
                              icon: Icons.layers_outlined,
                              label: 'Nomor Blok',
                              value: '#${detail.blockNumber}',
                            ),
                          _buildDetailItem(
                            icon: Icons.tag,
                            label: 'Transaction Hash',
                            value: detail.certificateTxHash!,
                            onCopy: () => _copyToClipboard(
                              detail.certificateTxHash!,
                              'Tx Hash',
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _isVerifying
                                      ? null
                                      : () => _verifyOnChain(
                                          detail.certificateTxHash!),
                                  icon: _isVerifying
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.security),
                                  label: Text(
                                    _isVerifying
                                        ? 'Memverifikasi...'
                                        : 'Verifikasi On-Chain',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade800,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    _openExplorer(detail.explorerUrl),
                                icon: const Icon(Icons.open_in_browser),
                                label: const Text('Explorer'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12, horizontal: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber.shade900),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Sertifikat ini sedang dalam antrean pencatatan ke blockchain BOT Chain oleh sistem relayer.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onCopy,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (onCopy != null)
            InkWell(
              onTap: onCopy,
              child: const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.copy, size: 16, color: Colors.blue),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGradeCard(String grade) {
    Color gradeColor;
    String gradeDesc;

    switch (grade.toUpperCase()) {
      case 'A':
        gradeColor = Colors.green.shade700;
        gradeDesc = 'Grade A — Layak Konsumsi Manusia (Food Bank)';
        break;
      case 'B':
        gradeColor = Colors.amber.shade800;
        gradeDesc = 'Grade B — Layak Pakan Ternak (Pabrik Pakan)';
        break;
      case 'C':
      default:
        gradeColor = Colors.deepOrange.shade800;
        gradeDesc = 'Grade C — Layak Kompos (Pengolahan Pupuk)';
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: gradeColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: gradeColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: gradeColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              grade.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              gradeDesc,
              style: TextStyle(
                color: gradeColor,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyTile(String code, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            code,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(double n) {
    return n.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
  }
}
