import 'package:flutter/material.dart';

/// Kategori pangan B2B
enum FoodCategory {
  dairy('Dairy', Icons.pets, Color(0xFF0077B6)),
  flour('Flour', Icons.grass, Color(0xFF92400E)),
  cookingOil('Cooking Oil', Icons.water_drop, Color(0xFF0077B6)),
  frozenFood('Frozen Food', Icons.ac_unit, Color(0xFF0891B2)),
  canned('Canned', Icons.inventory_2, Color(0xFFEA580C)),
  bakery('Bakery', Icons.bakery_dining, Color(0xFFD97706));

  const FoodCategory(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

/// Model produk katalog
class Product {
  final String id;
  final String name;
  final String supplier;
  final FoodCategory category;
  final double originalPrice;
  final double discountedPrice;
  final String unit;
  final int discountPercent;
  final int daysUntilExpiry;
  final double distanceKm;
  final String location;
  final String moq;
  final String? grade;
  final bool isLiveDutch;

  const Product({
    required this.id,
    required this.name,
    required this.supplier,
    required this.category,
    required this.originalPrice,
    required this.discountedPrice,
    required this.unit,
    required this.discountPercent,
    required this.daysUntilExpiry,
    required this.distanceKm,
    required this.location,
    required this.moq,
    this.grade,
    this.isLiveDutch = false,
  });
}

/// Data dummy untuk katalog
final List<Product> dummyProducts = [
  const Product(
    id: '1',
    name: 'Susu UHT Whole Milk Freshland 1L',
    supplier: 'PT Maju Pangan Abadi',
    category: FoodCategory.dairy,
    originalPrice: 15000,
    discountedPrice: 8250,
    unit: 'box',
    discountPercent: 45,
    daysUntilExpiry: 5,
    distanceKm: 1.2,
    location: 'Cimanggis',
    moq: '5 Box',
    isLiveDutch: true,
  ),
  const Product(
    id: '2',
    name: 'Minyak Goreng Kelapa Sawit Pouch 2L',
    supplier: 'CV Berkah Nabati',
    category: FoodCategory.cookingOil,
    originalPrice: 38000,
    discountedPrice: 23500,
    unit: 'pouch',
    discountPercent: 38,
    daysUntilExpiry: 3,
    distanceKm: 2.8,
    location: 'Depok',
    moq: '10 Pcs',
  ),
  const Product(
    id: '3',
    name: 'Keju Cheddar Olahan Blok Bakery 2kg',
    supplier: 'PT Prima Dairy Food',
    category: FoodCategory.dairy,
    originalPrice: 160000,
    discountedPrice: 79900,
    unit: 'blok',
    discountPercent: 50,
    daysUntilExpiry: 8,
    distanceKm: 4.1,
    location: 'Margonda',
    moq: '2 Blok',
    grade: 'Grade A',
  ),
  const Product(
    id: '4',
    name: 'Tepung Terigu Protein Tinggi 25kg',
    supplier: 'PT Bogasari Flour',
    category: FoodCategory.flour,
    originalPrice: 210000,
    discountedPrice: 147000,
    unit: 'sak',
    discountPercent: 30,
    daysUntilExpiry: 12,
    distanceKm: 5.6,
    location: 'Bogor',
    moq: '3 Sak',
  ),
  const Product(
    id: '5',
    name: 'Nugget Ayam Fiesta 1kg',
    supplier: 'PT Charoen Pokphand',
    category: FoodCategory.frozenFood,
    originalPrice: 65000,
    discountedPrice: 39000,
    unit: 'pack',
    discountPercent: 40,
    daysUntilExpiry: 7,
    distanceKm: 3.2,
    location: 'Cibinong',
    moq: '5 Pack',
  ),
  const Product(
    id: '6',
    name: 'Sarden Kaleng ABC 425g',
    supplier: 'PT Heinz ABC Indonesia',
    category: FoodCategory.canned,
    originalPrice: 22000,
    discountedPrice: 14300,
    unit: 'kaleng',
    discountPercent: 35,
    daysUntilExpiry: 14,
    distanceKm: 6.0,
    location: 'Bekasi',
    moq: '12 Kaleng',
  ),
];
