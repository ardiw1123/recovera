class EsgMonetaryValue {
  final double idr;
  final double usd;
  final double eur;
  final double gbp;

  const EsgMonetaryValue({
    required this.idr,
    required this.usd,
    required this.eur,
    required this.gbp,
  });

  factory EsgMonetaryValue.fromJson(Map<String, dynamic> json) {
    return EsgMonetaryValue(
      idr: (json['idr'] as num?)?.toDouble() ?? 0.0,
      usd: (json['usd'] as num?)?.toDouble() ?? 0.0,
      eur: (json['eur'] as num?)?.toDouble() ?? 0.0,
      gbp: (json['gbp'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'idr': idr,
    'usd': usd,
    'eur': eur,
    'gbp': gbp,
  };
}

class EsgCertificateListItem {
  final int id;
  final String certificateNo;
  final int listingId;
  final String productName;
  final String grade;
  final String blockchainStatus;
  final String createdAt;
  final double carbonSavedKg;
  final int qtyDiverted;
  final String offtakerName;
  final String? certificateTxHash;
  final int? blockNumber;

  const EsgCertificateListItem({
    required this.id,
    required this.certificateNo,
    required this.listingId,
    required this.productName,
    required this.grade,
    required this.blockchainStatus,
    required this.createdAt,
    required this.carbonSavedKg,
    required this.qtyDiverted,
    required this.offtakerName,
    this.certificateTxHash,
    this.blockNumber,
  });

  factory EsgCertificateListItem.fromJson(Map<String, dynamic> json) {
    return EsgCertificateListItem(
      id: json['id'] as int? ?? 0,
      certificateNo: json['certificate_no'] as String? ?? '-',
      listingId: json['listing_id'] as int? ?? 0,
      productName: json['product_name'] as String? ?? 'Produk Pangan',
      grade: json['grade'] as String? ?? 'A',
      blockchainStatus: json['blockchain_status'] as String? ?? 'Menunggu',
      createdAt: json['created_at'] as String? ?? '',
      carbonSavedKg: (json['carbon_saved_kg'] as num?)?.toDouble() ?? 0.0,
      qtyDiverted: json['qty_diverted'] as int? ?? 0,
      offtakerName: json['offtaker_name'] as String? ?? 'Mitra Pangan',
      certificateTxHash: json['certificate_tx_hash'] as String?,
      blockNumber: json['block_number'] as int?,
    );
  }
}

class EsgCertificateDetail {
  final int id;
  final String certificateNo;
  final int listingId;
  final String productName;
  final String offtakerName;
  final String offtakerType;
  final String grade;
  final int qtyDiverted;
  final double carbonSavedKg;
  final EsgMonetaryValue monetaryValue;
  final String issuedAtLondon;
  final String issuedAtWib;
  final String blockchainStatus;
  final String? certificateTxHash;
  final int? blockNumber;
  final String? explorerUrl;

  const EsgCertificateDetail({
    required this.id,
    required this.certificateNo,
    required this.listingId,
    required this.productName,
    required this.offtakerName,
    required this.offtakerType,
    required this.grade,
    required this.qtyDiverted,
    required this.carbonSavedKg,
    required this.monetaryValue,
    required this.issuedAtLondon,
    required this.issuedAtWib,
    required this.blockchainStatus,
    this.certificateTxHash,
    this.blockNumber,
    this.explorerUrl,
  });

  factory EsgCertificateDetail.fromJson(Map<String, dynamic> json) {
    return EsgCertificateDetail(
      id: json['id'] as int? ?? 0,
      certificateNo: json['certificate_no'] as String? ?? '-',
      listingId: json['listing_id'] as int? ?? 0,
      productName: json['product_name'] as String? ?? 'Produk Pangan',
      offtakerName: json['offtaker_name'] as String? ?? 'Mitra Food Bank',
      offtakerType: json['offtaker_type'] as String? ?? 'foodbank',
      grade: json['grade'] as String? ?? 'A',
      qtyDiverted: json['qty_diverted'] as int? ?? 0,
      carbonSavedKg: (json['carbon_saved_kg'] as num?)?.toDouble() ?? 0.0,
      monetaryValue: EsgMonetaryValue.fromJson(
        json['monetary_value'] as Map<String, dynamic>? ?? {},
      ),
      issuedAtLondon: json['issued_at_london'] as String? ?? '',
      issuedAtWib: json['issued_at_wib'] as String? ?? '',
      blockchainStatus: json['blockchain_status'] as String? ?? 'Menunggu',
      certificateTxHash: json['certificate_tx_hash'] as String?,
      blockNumber: json['block_number'] as int?,
      explorerUrl: json['explorer_url'] as String?,
    );
  }
}

/// Hasil simulasi diversion & penerbitan sertifikat ESG uji (endpoint dev-only).
class EsgDiversionTestResult {
  final int listingId;
  final int donationId;
  final String certificateNo;
  final String grade;
  final int qtyDiverted;
  final double carbonSavedKg;
  final String? certificateTxHash;
  final String blockchainStatus;

  const EsgDiversionTestResult({
    required this.listingId,
    required this.donationId,
    required this.certificateNo,
    required this.grade,
    required this.qtyDiverted,
    required this.carbonSavedKg,
    required this.blockchainStatus,
    this.certificateTxHash,
  });

  bool get isRecorded => blockchainStatus.toLowerCase() == 'tercatat';

  factory EsgDiversionTestResult.fromJson(Map<String, dynamic> json) {
    return EsgDiversionTestResult(
      listingId: json['listing_id'] as int? ?? 0,
      donationId: json['donation_id'] as int? ?? 0,
      certificateNo: json['certificate_no'] as String? ?? '-',
      grade: json['grade'] as String? ?? '-',
      qtyDiverted: json['qty_diverted'] as int? ?? 0,
      carbonSavedKg: (json['carbon_saved_kg'] as num?)?.toDouble() ?? 0.0,
      certificateTxHash: json['certificate_tx_hash'] as String?,
      blockchainStatus: json['blockchain_status'] as String? ?? 'Menunggu',
    );
  }
}

class BlockchainVerificationResult {
  final String txHash;
  final bool verified;
  final String status;
  final int? blockNumber;
  final String network;
  final String contractAddress;
  final String blockExplorerUrl;
  final String? verifiedAt;
  final String? certificateHashOnChain;

  const BlockchainVerificationResult({
    required this.txHash,
    required this.verified,
    required this.status,
    this.blockNumber,
    required this.network,
    required this.contractAddress,
    required this.blockExplorerUrl,
    this.verifiedAt,
    this.certificateHashOnChain,
  });

  factory BlockchainVerificationResult.fromJson(Map<String, dynamic> json) {
    return BlockchainVerificationResult(
      txHash: json['tx_hash'] as String? ?? '',
      verified: json['verified'] as bool? ?? false,
      status: json['status'] as String? ?? '',
      blockNumber: json['block_number'] as int?,
      network: json['network'] as String? ?? 'BOT Chain Testnet',
      contractAddress: json['contract_address'] as String? ?? '',
      blockExplorerUrl: json['block_explorer_url'] as String? ?? '',
      verifiedAt: json['verified_at'] as String?,
      certificateHashOnChain: json['certificate_hash_on_chain'] as String?,
    );
  }
}
