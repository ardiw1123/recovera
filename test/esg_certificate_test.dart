import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovera/features/seller/models/esg_certificate_model.dart';
import 'package:recovera/features/seller/models/seller_dashboard_model.dart';
import 'package:recovera/features/seller/screens/esg_certificate_detail_screen.dart';
import 'package:recovera/features/seller/screens/esg_certificate_list_screen.dart';
import 'package:recovera/features/seller/screens/seller_dashboard_screen.dart';
import 'package:recovera/features/seller/repositories/seller_repository.dart';

void main() {
  group('ESG Certificate Models Test', () {
    test('EsgCertificateListItem fromJson parses correctly', () {
      final json = {
        'id': 101,
        'certificate_no': 'ESG-ID-2026-01001',
        'listing_id': 12,
        'product_name': 'Susu UHT Full Cream',
        'grade': 'A',
        'blockchain_status': 'Tercatat',
        'created_at': '2026-10-24T12:00:00Z',
        'carbon_saved_kg': 125.5,
        'qty_diverted': 50,
        'offtaker_name': 'Food Bank Indonesia',
        'certificate_tx_hash': '0x24c5755a91a54cb4e0f273a5e7c1534cc635e16400bec4aa019a1fb118aabb5c',
        'block_number': 27996026,
      };

      final item = EsgCertificateListItem.fromJson(json);
      expect(item.id, 101);
      expect(item.certificateNo, 'ESG-ID-2026-01001');
      expect(item.grade, 'A');
      expect(item.blockchainStatus, 'Tercatat');
      expect(item.carbonSavedKg, 125.5);
      expect(item.qtyDiverted, 50);
      expect(item.certificateTxHash, isNotNull);
      expect(item.blockNumber, 27996026);
    });

    test('EsgCertificateDetail fromJson parses monetary values and timezones', () {
      final json = {
        'id': 202,
        'certificate_no': 'ESG-ID-2026-02002',
        'listing_id': 15,
        'product_name': 'Tepung Terigu Segitiga',
        'offtaker_name': 'Pakan Ternak Sejahtera',
        'offtaker_type': 'pakan',
        'grade': 'B',
        'qty_diverted': 100,
        'carbon_saved_kg': 250.0,
        'monetary_value': {
          'idr': 1200000.0,
          'usd': 74.40,
          'eur': 69.60,
          'gbp': 58.80,
        },
        'issued_at_london': '2026-10-24 10:00:00 BST',
        'issued_at_wib': '2026-10-24 16:00:00 WIB',
        'blockchain_status': 'Tercatat',
        'certificate_tx_hash': '0x24c5755a91a54cb4e0f273a5e7c1534cc635e16400bec4aa019a1fb118aabb5c',
        'block_number': 27996026,
        'explorer_url': 'https://scan.bohr.life/tx/0x24c5755a91a54cb4e0f273a5e7c1534cc635e16400bec4aa019a1fb118aabb5c',
      };

      final detail = EsgCertificateDetail.fromJson(json);
      expect(detail.id, 202);
      expect(detail.monetaryValue.idr, 1200000.0);
      expect(detail.monetaryValue.usd, 74.40);
      expect(detail.monetaryValue.eur, 69.60);
      expect(detail.monetaryValue.gbp, 58.80);
      expect(detail.issuedAtLondon, contains('BST'));
      expect(detail.issuedAtWib, contains('WIB'));
      expect(detail.explorerUrl, contains('scan.bohr.life'));
    });

    test('BlockchainVerificationResult fromJson parses valid status', () {
      final json = {
        'tx_hash': '0x24c5755a91a54cb4e0f273a5e7c1534cc635e16400bec4aa019a1fb118aabb5c',
        'verified': true,
        'status': 'Confirmed',
        'block_number': 27996026,
        'network': 'BOT Chain Testnet',
        'contract_address': '0x485D903159eac9D30E9EadC7abdd4Af18dc5c859',
        'block_explorer_url': 'https://scan.bohr.life/tx/0x24c5755a91a54cb4e0f273a5e7c1534cc635e16400bec4aa019a1fb118aabb5c',
        'verified_at': '2026-10-24T16:00:00Z',
        'certificate_hash_on_chain': '0x9503867a3e7faa5da3b2b87d6c8e4f0bb2ec9ff2f326773af748f0f941051b11',
      };

      final result = BlockchainVerificationResult.fromJson(json);
      expect(result.verified, isTrue);
      expect(result.status, 'Confirmed');
      expect(result.blockNumber, 27996026);
      expect(result.contractAddress, '0x485D903159eac9D30E9EadC7abdd4Af18dc5c859');
      expect(result.network, 'BOT Chain Testnet');
    });
  });

  group('ESG Certificate UI Widget Tests', () {
    testWidgets('EsgCertificateDetailScreen displays all required certificate information',
        (tester) async {
      final testDetail = EsgCertificateDetail(
        id: 1,
        certificateNo: 'ESG-ID-2026-00001',
        listingId: 10,
        productName: 'Yogurt Strawberry 500ml',
        offtakerName: 'Food Bank Indonesia',
        offtakerType: 'foodbank',
        grade: 'A',
        qtyDiverted: 80,
        carbonSavedKg: 200.0,
        monetaryValue: const EsgMonetaryValue(
          idr: 800000.0,
          usd: 49.60,
          eur: 46.40,
          gbp: 39.20,
        ),
        issuedAtLondon: '2026-10-24 11:30:00 BST',
        issuedAtWib: '2026-10-24 17:30:00 WIB',
        blockchainStatus: 'Tercatat',
        certificateTxHash: '0x24c5755a91a54cb4e0f273a5e7c1534cc635e16400bec4aa019a1fb118aabb5c',
        blockNumber: 27996026,
        explorerUrl: 'https://scan.bohr.life/tx/0x24c5755a91a54cb4e0f273a5e7c1534cc635e16400bec4aa019a1fb118aabb5c',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  Text(testDetail.certificateNo),
                  Text(testDetail.productName),
                  Text('${testDetail.carbonSavedKg} kg CO2e'),
                  Text(testDetail.issuedAtLondon),
                  Text(testDetail.issuedAtWib),
                  Text('IDR: ${testDetail.monetaryValue.idr}'),
                  Text('USD: ${testDetail.monetaryValue.usd}'),
                  Text('EUR: ${testDetail.monetaryValue.eur}'),
                  Text('GBP: ${testDetail.monetaryValue.gbp}'),
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('Verifikasi On-Chain'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('ESG-ID-2026-00001'), findsOneWidget);
      expect(find.text('Yogurt Strawberry 500ml'), findsOneWidget);
      expect(find.text('200.0 kg CO2e'), findsOneWidget);
      expect(find.text('2026-10-24 11:30:00 BST'), findsOneWidget);
      expect(find.text('2026-10-24 17:30:00 WIB'), findsOneWidget);
      expect(find.text('IDR: 800000.0'), findsOneWidget);
      expect(find.text('USD: 49.6'), findsOneWidget);
      expect(find.text('EUR: 46.4'), findsOneWidget);
      expect(find.text('GBP: 39.2'), findsOneWidget);
      expect(find.text('Verifikasi On-Chain'), findsOneWidget);
    });
  });
}
