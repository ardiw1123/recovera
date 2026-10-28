import 'package:flutter/material.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/order_repository.dart';
import 'buyer_transaction_screen.dart';
import 'seller_order_screen.dart';

/// Halaman Transaksi Utama yang beradaptasi secara otomatis sesuai role:
/// • Jika role adalah Penjual (Seller) -> Menampilkan SellerOrderScreen
/// • Jika role adalah Pembeli (Buyer) -> Menampilkan BuyerTransactionScreen
/// Tanpa tombol toggle mode role di dalam UI, dan tanpa fitur rating.
class TransactionHistoryScreen extends StatelessWidget {
  const TransactionHistoryScreen({
    super.key,
    this.orderRepository,
    this.isSeller,
  });

  final OrderRepository? orderRepository;
  final bool? isSeller;

  @override
  Widget build(BuildContext context) {
    final bool isUserSeller = isSeller ?? AuthRepository.instance.isSeller;

    if (isUserSeller) {
      return SellerOrderScreen(
        orderRepository: orderRepository,
      );
    } else {
      return BuyerTransactionScreen(
        orderRepository: orderRepository,
      );
    }
  }
}
