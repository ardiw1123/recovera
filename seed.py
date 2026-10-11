"""
Recovera — Comprehensive Database Seeder (1000+ Baris Data Realistis Indonesia)
Mencakup:
- Seluruh kota besar di Indonesia dengan koordinat geografis nyata
- 50+ Produk pangan B2B nyata di pasar Indonesia (Dairy, Frozen, Grain, Oil, Canned, Beverage)
- 1000 Baris Listings (Dutch Auction) lengkap dengan status active, sold, dan diverted
- Sellers (Distributor), Buyers (UMKM), Offtakers (Food Bank), Orders, Donations, Feedback
"""

import sys
import urllib.parse
import random
from datetime import datetime, timedelta, timezone

# Force stdout ke UTF-8 agar print emoji di Windows terminal tidak error:
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

import bcrypt
from faker import Faker
from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker
from sqlalchemy import (
    Column, Integer, String, Text, Boolean, Numeric, 
    DateTime, Date, BigInteger, ForeignKey, JSON
)

# Password di-encode otomatis agar karakter unik (?, !, *) aman di URL parser:
_raw_password = "Ny37V7?Fh!*Gysp"
_encoded_password = urllib.parse.quote_plus(_raw_password)

# Gunakan Supabase IPv4 Pooler URL (stabil di semua jaringan Windows):
DATABASE_URL = f"postgresql+psycopg2://postgres.wvlaqrbsikytzflkeeqx:{_encoded_password}@aws-0-ap-southeast-1.pooler.supabase.com:6543/postgres"

engine = create_engine(DATABASE_URL, pool_size=10, max_overflow=0)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
db = SessionLocal()

fake = Faker("id_ID")
Base = declarative_base()

# ==============================================================================
# 2. DEFINISI MODEL ORM SESUAI SCHEMA
# ==============================================================================
class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True)
    email = Column(String, unique=True, nullable=False)
    password_hash = Column(String, nullable=False)
    role = Column(String, nullable=False)
    name = Column(String, nullable=False)
    phone = Column(String)
    photo_url = Column(Text)
    created_at = Column(DateTime, default=datetime.utcnow)

class Seller(Base):
    __tablename__ = "sellers"
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    company_name = Column(String, nullable=False)
    address = Column(Text, nullable=False)
    warehouse_lat = Column(Numeric, nullable=False)
    warehouse_lng = Column(Numeric, nullable=False)
    city = Column(String, nullable=False)

class Buyer(Base):
    __tablename__ = "buyers"
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    business_type = Column(String, nullable=False)
    address = Column(Text, nullable=False)
    base_lat = Column(Numeric, nullable=False)
    base_lng = Column(Numeric, nullable=False)
    pref_categories = Column(JSON, nullable=False)
    max_radius_km = Column(Integer, default=15)
    has_cold_storage = Column(Boolean, default=False)
    total_orders_completed = Column(Integer, default=0)
    payment_reliability_score = Column(Numeric, default=1.00)

class Product(Base):
    __tablename__ = "products"
    id = Column(Integer, primary_key=True)
    sku = Column(String, unique=True, nullable=False)
    barcode = Column(String)
    name = Column(String, nullable=False)
    brand = Column(String)
    category = Column(String, nullable=False)
    storage_type = Column(String, nullable=False)
    default_unit = Column(String, nullable=False)
    image_url = Column(Text)

class Listing(Base):
    __tablename__ = "listings"
    id = Column(Integer, primary_key=True)
    product_id = Column(Integer, ForeignKey("products.id"))
    seller_id = Column(Integer, ForeignKey("sellers.id"))
    batch_number = Column(String, nullable=False)
    qty = Column(Integer, nullable=False)
    normal_price = Column(Numeric, nullable=False)
    start_price = Column(Numeric, nullable=False)
    min_price = Column(Numeric, nullable=False)
    drop_interval_minutes = Column(Integer, default=60)
    drop_percentage = Column(Numeric, default=2.50)
    expiry_date = Column(Date, nullable=False)
    auction_start_at = Column(DateTime, nullable=False)
    auction_end_at = Column(DateTime, nullable=False)
    status = Column(String, default="active")
    created_at = Column(DateTime, default=datetime.utcnow)

class Offer(Base):
    __tablename__ = "offers"
    id = Column(Integer, primary_key=True)
    listing_id = Column(Integer, ForeignKey("listings.id"))
    buyer_id = Column(Integer, ForeignKey("buyers.id"))
    match_score = Column(Numeric, nullable=False)
    distance_km = Column(Numeric, nullable=False)
    days_to_expiry = Column(Integer, nullable=False)
    offered_discount_pct = Column(Numeric, nullable=False)
    status = Column(String, default="sent")
    sent_at = Column(DateTime, default=datetime.utcnow)
    responded_at = Column(DateTime)

class Order(Base):
    __tablename__ = "orders"
    id = Column(Integer, primary_key=True)
    listing_id = Column(Integer, ForeignKey("listings.id"))
    buyer_id = Column(Integer, ForeignKey("buyers.id"))
    qty = Column(Integer, nullable=False)
    final_unit_price = Column(Numeric, nullable=False)
    total_price = Column(Numeric, nullable=False)
    status = Column(String, default="paid")
    created_at = Column(DateTime, default=datetime.utcnow)

class Offtaker(Base):
    __tablename__ = "offtakers"
    id = Column(Integer, primary_key=True)
    name = Column(String, nullable=False)
    type = Column(String, nullable=False)
    lat = Column(Numeric, nullable=False)
    lng = Column(Numeric, nullable=False)
    address = Column(Text, nullable=False)
    contact = Column(String, nullable=False)

class Donation(Base):
    __tablename__ = "donations"
    id = Column(Integer, primary_key=True)
    listing_id = Column(Integer, ForeignKey("listings.id"), unique=True)
    offtaker_id = Column(Integer, ForeignKey("offtakers.id"))
    grade = Column(String, nullable=False)
    qty_diverted = Column(Integer, nullable=False)
    carbon_saved_kg = Column(Numeric, nullable=False)
    certificate_no = Column(String, unique=True, nullable=False)
    certificate_tx_hash = Column(String)
    block_number = Column(BigInteger)
    created_at = Column(DateTime, default=datetime.utcnow)

class CourseFeedback(Base):
    __tablename__ = "course_feedbacks"
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    kesan = Column(Text, nullable=False)
    saran = Column(Text, nullable=False)
    submitted_at = Column(DateTime, default=datetime.utcnow)

# ==============================================================================
# 3. BANK DATA REALISTIS INDONESIA
# ==============================================================================

# Kota-kota Besar Indonesia beserta Titik Koordinat Pusatnya (Lat, Lng)
INDONESIAN_CITIES = [
    {"city": "Surabaya", "lat": -7.2575, "lng": 112.7521},
    {"city": "Sidoarjo", "lat": -7.4478, "lng": 112.7183},
    {"city": "Jakarta Barat", "lat": -6.1683, "lng": 106.7588},
    {"city": "Jakarta Timur", "lat": -6.2250, "lng": 106.9004},
    {"city": "Jakarta Selatan", "lat": -6.2615, "lng": 106.8106},
    {"city": "Tangerang", "lat": -6.1783, "lng": 106.6319},
    {"city": "Bekasi", "lat": -6.2383, "lng": 106.9756},
    {"city": "Bandung", "lat": -6.9175, "lng": 107.6191},
    {"city": "Semarang", "lat": -6.9932, "lng": 110.4203},
    {"city": "Yogyakarta", "lat": -7.7956, "lng": 110.3695},
    {"city": "Malang", "lat": -7.9666, "lng": 112.6326},
    {"city": "Medan", "lat": 3.5952, "lng": 98.6722},
    {"city": "Makassar", "lat": -5.1477, "lng": 119.4327},
    {"city": "Denpasar", "lat": -8.6705, "lng": 115.2126},
    {"city": "Palembang", "lat": -2.9761, "lng": 104.7754},
]

# Katalog Master 50 Produk Pangan B2B Nyata di Indonesia
INDONESIAN_PRODUCTS_MASTER = [
    # Dairy (Chilled/Cold)
    ("SKU-DAIRY-01", "8991001001", "Susu UHT Ultra Milk Full Cream 1L", "Ultra Jaya", "Dairy", "chilled", "karton (12 pcs)", "https://images.unsplash.com/photo-1550583724-b2692b85b150?w=500"),
    ("SKU-DAIRY-02", "8991001002", "Susu UHT Diamond Full Cream 1L", "Diamond", "Dairy", "chilled", "karton (12 pcs)", "https://images.unsplash.com/photo-1563636619-e9143da7973b?w=500"),
    ("SKU-DAIRY-03", "8991001003", "Greenfields Fresh Milk Pasteurisasi 1L", "Greenfields", "Dairy", "chilled", "karton (12 pcs)", "https://images.unsplash.com/photo-1528750997573-59b89d56f4f7?w=500"),
    ("SKU-DAIRY-04", "8991001004", "Keju Cheddar Olahan Kraft 2kg (Block)", "Kraft", "Dairy", "chilled", "karton (8 block)", "https://images.unsplash.com/photo-1486297678162-eb2a19b0a32d?w=500"),
    ("SKU-DAIRY-05", "8991001005", "Keju Prochiz Gold Cheddar 2kg", "Prochiz", "Dairy", "chilled", "karton (8 block)", "https://images.unsplash.com/photo-1618160702438-9b02ab6515c9?w=500"),
    ("SKU-DAIRY-06", "8991001006", "Anchor Unsalted Butter 1kg", "Anchor", "Dairy", "chilled", "karton (10 pcs)", "https://images.unsplash.com/photo-1589985270826-4b7bb135bc9d?w=500"),
    ("SKU-DAIRY-07", "8991001007", "Whipping Cream Dairy Anchor 1L", "Anchor", "Dairy", "chilled", "karton (12 pcs)", "https://images.unsplash.com/photo-1550583724-b2692b85b150?w=500"),
    ("SKU-DAIRY-08", "8991001008", "Cimory Fresh Milk UHT Cokelat 950ml", "Cimory", "Dairy", "chilled", "karton (12 pcs)", "https://images.unsplash.com/photo-1563636619-e9143da7973b?w=500"),

    # Flour & Grain (Ambient)
    ("SKU-FLOUR-01", "8992002001", "Tepung Terigu Segitiga Biru 25kg (Sak)", "Bogasari", "Flour & Grain", "ambient", "sak (25 kg)", "https://images.unsplash.com/photo-1509440159596-0249088772ff?w=500"),
    ("SKU-FLOUR-02", "8992002002", "Tepung Terigu Cakra Kembar Emas 25kg", "Bogasari", "Flour & Grain", "ambient", "sak (25 kg)", "https://images.unsplash.com/photo-1574323347407-f5e1ad6d020b?w=500"),
    ("SKU-FLOUR-03", "8992002003", "Tepung Terigu Kunci Biru 25kg (Sak)", "Bogasari", "Flour & Grain", "ambient", "sak (25 kg)", "https://images.unsplash.com/photo-1509440159596-0249088772ff?w=500"),
    ("SKU-FLOUR-04", "8992002004", "Tepung Beras Putih Rose Brand 500g", "Rose Brand", "Flour & Grain", "ambient", "karton (20 pcs)", "https://images.unsplash.com/photo-1586201375761-83865001e31c?w=500"),
    ("SKU-FLOUR-05", "8992002005", "Tepung Tapioka Cap Orang Desa 25kg", "Lautan Luas", "Flour & Grain", "ambient", "sak (25 kg)", "https://images.unsplash.com/photo-1586201375761-83865001e31c?w=500"),
    ("SKU-FLOUR-06", "8992002006", "Beras Ramos Premium Maknyuss 25kg", "TPS Food", "Flour & Grain", "ambient", "karung (25 kg)", "https://images.unsplash.com/photo-1586201375761-83865001e31c?w=500"),
    ("SKU-FLOUR-07", "8992002007", "Beras Sania Premium Pandan Wangi 20kg", "Wilmar", "Flour & Grain", "ambient", "karung (20 kg)", "https://images.unsplash.com/photo-1586201375761-83865001e31c?w=500"),

    # Oil & Margarine (Ambient)
    ("SKU-OIL-01", "8993003001", "Minyak Goreng Sawit Bimoli Klasik 18L", "Salim Ivomas", "Oil", "ambient", "jerigen (18L)", "https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?w=500"),
    ("SKU-OIL-02", "8993003002", "Minyak Goreng Sania Royale 2L (Pouch)", "Wilmar", "Oil", "ambient", "karton (6 pouch)", "https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?w=500"),
    ("SKU-OIL-03", "8993003003", "Minyak Goreng SunCo 2L", "Musim Mas", "Oil", "ambient", "karton (6 pouch)", "https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?w=500"),
    ("SKU-OIL-04", "8993003004", "Minyak Goreng Filma Non Kolesterol 2L", "SMART", "Oil", "ambient", "karton (6 pouch)", "https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?w=500"),
    ("SKU-OIL-05", "8993003005", "Margarin Serbaguna Blue Band Master 15kg", "Upfield", "Oil", "ambient", "karton (15 kg)", "https://images.unsplash.com/photo-1589985270826-4b7bb135bc9d?w=500"),
    ("SKU-OIL-06", "8993003006", "Margarin Filma Baker's Fat 15kg", "SMART", "Oil", "ambient", "karton (15 kg)", "https://images.unsplash.com/photo-1589985270826-4b7bb135bc9d?w=500"),

    # Frozen Food (Frozen)
    ("SKU-FROZEN-01", "8994004001", "Fiesta Chicken Nugget Crispy 1kg", "Charoen Pokphand", "Frozen", "frozen", "karton (10 pcs)", "https://images.unsplash.com/photo-1562967914-608f82629710?w=500"),
    ("SKU-FROZEN-02", "8994004002", "Kanzler Sosis Sapi Frankfurter Cocktail 1kg", "Macroprima", "Frozen", "frozen", "karton (10 pcs)", "https://images.unsplash.com/photo-1585325701165-351af916e581?w=500"),
    ("SKU-FROZEN-03", "8994004003", "Champ Sosis Ayam Bakar 1kg", "Charoen Pokphand", "Frozen", "frozen", "karton (12 pcs)", "https://images.unsplash.com/photo-1585325701165-351af916e581?w=500"),
    ("SKU-FROZEN-04", "8994004004", "Belfoods Favorite Chicken Nugget 500g", "Belfoods", "Frozen", "frozen", "karton (12 pcs)", "https://images.unsplash.com/photo-1562967914-608f82629710?w=500"),
    ("SKU-FROZEN-05", "8994004005", "Daging Sapi US Shortplate Beef Slice 1kg", "Santori", "Frozen", "frozen", "box (10 kg)", "https://images.unsplash.com/photo-1603048588665-791ca8aea617?w=500"),
    ("SKU-FROZEN-06", "8994004006", "Udang Vaname Kupas Beku Peeled 1kg", "CP Prima", "Frozen", "frozen", "karton (10 pack)", "https://images.unsplash.com/photo-1565680018434-b513d5e5fd47?w=500"),
    ("SKU-FROZEN-07", "8994004007", "French Fries Aviko Shoestring 2.5kg", "Aviko", "Frozen", "frozen", "karton (4 pack)", "https://images.unsplash.com/photo-1573080496219-bb080dd4f877?w=500"),

    # Beverage (Ambient)
    ("SKU-BEV-01", "8995005001", "Teh Botol Sosro Kemasan Kotak 250ml", "Sosro", "Beverage", "ambient", "karton (24 pcs)", "https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=500"),
    ("SKU-BEV-02", "8995005002", "Teh Pucuk Harum Melati 350ml", "Mayora", "Beverage", "ambient", "karton (24 btl)", "https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=500"),
    ("SKU-BEV-03", "8995005003", "Kopi Kapal Api Special Mix Renceng", "Santos Jaya Abadi", "Beverage", "ambient", "karton (12 renceng)", "https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?w=500"),
    ("SKU-BEV-04", "8995005004", "Buavita Jus Jeruk Asli 1L", "Unilever", "Beverage", "ambient", "karton (12 pcs)", "https://images.unsplash.com/photo-1613478223719-2ab802602423?w=500"),
    ("SKU-BEV-05", "8995005005", "Hydro Coco Air Kelapa Asli 1L", "Kalbe", "Beverage", "ambient", "karton (12 pcs)", "https://images.unsplash.com/photo-1525385133512-2f3bdd039054?w=500"),
    ("SKU-BEV-06", "8995005006", "Susu Kental Manis Frisian Flag Gold 560g", "Frisian Flag", "Beverage", "ambient", "karton (24 pouch)", "https://images.unsplash.com/photo-1563636619-e9143da7973b?w=500"),

    # Canned & Condiments (Ambient)
    ("SKU-CANNED-01", "8996006001", "Kornet Daging Sapi Pronas Corned Beef 340g", "Pronas", "Canned", "ambient", "karton (24 kaleng)", "https://images.unsplash.com/photo-1534939561126-855b8675edd7?w=500"),
    ("SKU-CANNED-02", "8996006002", "Ikan Sarden Saus Tomat ABC 425g", "Kraft Heinz ABC", "Canned", "ambient", "karton (24 kaleng)", "https://images.unsplash.com/photo-1534939561126-855b8675edd7?w=500"),
    ("SKU-CANNED-03", "8996006003", "Kecap Manis Bango Jerigen 1.35L", "Unilever", "Canned", "ambient", "karton (6 jerigen)", "https://images.unsplash.com/photo-1472476443507-c7a5948772fc?w=500"),
    ("SKU-CANNED-04", "8996006004", "Saus Sambal Extra Pedas Indofood 1kg (Pouch)", "Indofood", "Canned", "ambient", "karton (12 pouch)", "https://images.unsplash.com/photo-1472476443507-c7a5948772fc?w=500"),
    ("SKU-CANNED-05", "8996006005", "Santan Kelapa Siap Pakai Kara 1L (UHT)", "Kara Santan", "Canned", "ambient", "karton (12 pcs)", "https://images.unsplash.com/photo-1550583724-b2692b85b150?w=500"),
    ("SKU-CANNED-06", "8996006006", "Mayonnaise Maestro Original 1kg", "Maestro", "Canned", "ambient", "karton (12 pouch)", "https://images.unsplash.com/photo-1472476443507-c7a5948772fc?w=500"),
    ("SKU-CANNED-07", "8996006007", "Pasta Tomat Del Monte 3kg (Kaleng Besar)", "Del Monte", "Canned", "ambient", "karton (6 kaleng)", "https://images.unsplash.com/photo-1534939561126-855b8675edd7?w=500"),
    ("SKU-CANNED-08", "8996006008", "Madu Murni Nusantara Jerigen 2kg", "Madu Nusantara", "Canned", "ambient", "karton (6 jerigen)", "https://images.unsplash.com/photo-1587049352846-4a222e784d38?w=500"),
]

# Nama Perusahaan Distributor Indonesia
SELLER_COMPANIES = [
    "PT Sumber Pangan Makmur Abadi", "CV Berkah Jaya Logistik", "PT Trisula Boga Mandiri",
    "PT Lautan Pangan Nusantara", "UD Tani Makmur Sejahtera", "PT Sarana Distribusi Nusantara",
    "CV Bintang Terang Pangan", "PT Sinar Agro Niaga", "PT Graha Kuliner Distribusi",
    "CV Mutiara Segar Logistik", "PT Kencana Pangan Mandiri", "UD Harapan Baru Distribusi",
    "PT Wahana Boga Utama", "CV Citra Sembako Indonesia", "PT Sentosa Distribusi Pangan",
    "PT Sukses Makmur Distribindo", "CV Andalan Mitra Grosir", "PT Mega Niaga Pangan",
    "UD Berkah Sinar Surya", "PT Pasifik Food Distribution", "PT Anugerah Jaya Distribusi",
    "CV Logistik Kuliner Indonesia", "PT Riau Pangan Lestari", "PT Delta Food Supplies",
    "UD Prima Rasa Logistik"
]

# Nama Usaha UMKM Kuliner Indonesia
BUYER_BUSINESS_PREFIXES = [
    ("bakery", ["Roti Manis Bahari", "Dapur Roti Bu Sri", "Bakery Mawar Indah", "Aroma Pastry & Bread", "Roti Bakar Barokah", "Holland Bakery Jaya", "Cake & Pastry Bu Maya"]),
    ("katering", ["Katering Berkah Bunda", "Katering Selera Nusantara", "Dapur Katering Barokah", "Katering Bu Broto", "Pesta Rasa Katering", "Mitra Mandiri Catering"]),
    ("resto", ["Restoran Padang Salero Bundo", "Rumah Makan Sederhana Roso", "Dapur Nasi Goreng Gila", "Warung Soto Ayam Lamongan Cak Har", "Depot Bu Rudy Maknyus", "Ayam Geprek Sambal Bawang Juara"]),
    ("warung", ["Warung Nasi Bu Siti", "Warung Sembako Barokah", "Kedai Kopi & Toast Nusantara", "Warung Makan Barokah Mbak Tutik", "Depot Makanan Berkah Sejahtera"])
]

# Mitra Pengalihan / Lembaga Daur Ulang Pangan Zero-Waste
OFFTAKERS_DATA = [
    ("Food Bank Indonesia (FBI) Regional Jatim", "foodbank", -7.2600, 112.7450, "Jl. Raya Darmo No. 45, Wonokromo, Surabaya", "081234567801"),
    ("Garda Pangan Surplus Food Rescue Surabaya", "foodbank", -7.2850, 112.7200, "Jl. Mayjen Sungkono No. 88, Dukuh Pakis, Surabaya", "081234567802"),
    ("Bank Makanan Indonesia Cabang Jabodetabek", "foodbank", -6.2150, 106.8400, "Jl. Tebet Barat Dalam Raya No. 12, Jakarta Selatan", "081234567803"),
    ("Pabrik Pakan Ternak Berkah Agro Mandiri", "animal_feed", -7.4200, 112.6900, "Kawasan Industri Buduran No. 10, Sidoarjo", "081234567804"),
    ("Sentra Pakan Ternak Subur Sidoarjo", "animal_feed", -7.4500, 112.7300, "Jl. Raya Candi No. 56, Sidoarjo", "081234567805"),
    ("Fasilitas Pengomposan Organik Lestari Surabaya", "compost", -7.3100, 112.7800, "Jl. Rungkut Industri II No. 25, Surabaya", "081234567806"),
    ("Pusat Pengolahan Pupuk Kompos Pupuk Sriwijaya", "compost", -6.1900, 106.7200, "Jl. Daan Mogot Km. 14 No. 7, Jakarta Barat", "081234567807"),
    ("Yayasan Penyelamat Pangan Hijau Bandung", "foodbank", -6.9200, 107.6000, "Jl. Buah Batu No. 102, Lengkong, Bandung", "081234567808"),
]

# ==============================================================================
# 4. EKSEKUSI SEEDER LENGKAP
# ==============================================================================
def seed_database():
    print("==================================================================")
    print("🚀 MEMULAI SEEDER RECOVERA: 1000+ DATA REALISTIS INDONESIA")
    print("==================================================================")

    # Pastikan seluruh tabel di Supabase sudah terbuat otomatis jika belum ada:
    print("🛠️ Memastikan tabel-tabel di Supabase sudah siap...")
    Base.metadata.create_all(bind=engine)

    # 1 Password Hash Baku untuk Semua Akun Demo
    print("🔑 Mengenerate hash password standar (Password123!)...")
    default_password_hash = bcrypt.hashpw(b"Password123!", bcrypt.gensalt()).decode("utf-8")

    # --------------------------------------------------------------------------
    # LEVEL 1: MASTER DATA
    # --------------------------------------------------------------------------
    print("📦 [1/6] Menyimpan 8 Lembaga Offtaker (Food Bank / Pakan / Kompos)...")
    offtakers = [
        Offtaker(name=d[0], type=d[1], lat=d[2], lng=d[3], address=d[4], contact=d[5])
        for d in OFFTAKERS_DATA
    ]
    db.add_all(offtakers)
    db.flush()

    print("🛒 [2/6] Menyimpan 40+ Master Produk Pangan Indonesia...")
    products = [
        Product(sku=p[0], barcode=p[1], name=p[2], brand=p[3], category=p[4], storage_type=p[5], default_unit=p[6], image_url=p[7])
        for p in INDONESIAN_PRODUCTS_MASTER
    ]
    db.add_all(products)
    db.flush()

    # --------------------------------------------------------------------------
    # LEVEL 2: USERS, SELLERS (DISTRIBUTOR) & BUYERS (UMKM)
    # --------------------------------------------------------------------------
    print("👥 [3/6] Mengenerate 50 Distributor Seller & 100 Pembeli UMKM...")
    sellers_list = []
    seller_counter = 1

    # 50 Seller di berbagai kota Indonesia
    for i in range(50):
        city_info = INDONESIAN_CITIES[i % len(INDONESIAN_CITIES)]
        seller_user = User(
            email=f"seller{seller_counter}@recovera.id",
            password_hash=default_password_hash,
            role="seller",
            name=fake.name(),
            phone=fake.phone_number(),
            photo_url=f"https://i.pravatar.cc/150?u=seller{seller_counter}"
        )
        db.add(seller_user)
        db.flush()

        comp_name = SELLER_COMPANIES[i % len(SELLER_COMPANIES)]
        if i >= len(SELLER_COMPANIES):
            comp_name += f" Cabang {city_info['city']}"

        seller_profile = Seller(
            user_id=seller_user.id,
            company_name=comp_name,
            address=f"Kawasan Pergudangan {fake.street_name()} No. {random.randint(10, 200)}, {city_info['city']}",
            warehouse_lat=city_info["lat"] + random.uniform(-0.04, 0.04),
            warehouse_lng=city_info["lng"] + random.uniform(-0.04, 0.04),
            city=city_info["city"]
        )
        db.add(seller_profile)
        db.flush()
        sellers_list.append((seller_profile, city_info))
        seller_counter += 1

    # 100 Buyer UMKM di sekitar seller
    buyers_list = []
    buyer_counter = 1
    for i in range(100):
        matched_seller_city = sellers_list[i % len(sellers_list)][1]
        b_type, prefixes = random.choice(BUYER_BUSINESS_PREFIXES)
        business_title = f"{random.choice(prefixes)} {fake.first_name()}"

        buyer_user = User(
            email=f"buyer{buyer_counter}@recovera.id",
            password_hash=default_password_hash,
            role="buyer",
            name=fake.name(),
            phone=fake.phone_number(),
            photo_url=f"https://i.pravatar.cc/150?u=buyer{buyer_counter}"
        )
        db.add(buyer_user)
        db.flush()

        buyer_profile = Buyer(
            user_id=buyer_user.id,
            business_type=b_type,
            address=f"Jl. {fake.street_name()} No. {random.randint(1, 99)}, {matched_seller_city['city']}",
            base_lat=matched_seller_city["lat"] + random.uniform(-0.05, 0.05),
            base_lng=matched_seller_city["lng"] + random.uniform(-0.05, 0.05),
            pref_categories=random.sample(["Dairy", "Flour & Grain", "Oil", "Frozen", "Canned", "Beverage"], k=random.randint(2, 4)),
            max_radius_km=random.choice([10, 15, 20]),
            has_cold_storage=(b_type in ["bakery", "resto"] or random.choice([True, False])),
            total_orders_completed=random.randint(0, 25),
            payment_reliability_score=round(random.uniform(0.80, 1.00), 2)
        )
        db.add(buyer_profile)
        db.flush()
        buyers_list.append(buyer_profile)
        buyer_counter += 1

    # --------------------------------------------------------------------------
    # LEVEL 3: 1000 LISTINGS (DUTCH AUCTION BATCH)
    # --------------------------------------------------------------------------
    print("🏷️  [4/6] Menghasilkan 1.000 Baris Data Lelang (Dutch Auction Listings)...")
    now = datetime.now(timezone.utc)
    listings_list = []

    # Harga acuan normal sesuai produk
    price_ranges = [120000, 185000, 250000, 380000, 450000, 620000, 850000, 1200000]

    for i in range(1000):
        chosen_product = random.choice(products)
        chosen_seller, seller_city = random.choice(sellers_list)

        normal_price = random.choice(price_ranges)
        # Sesuai aturan Dutch Auction di PRD: Diskon awal 25% - 50%
        initial_discount = random.choice([0.25, 0.30, 0.40, 0.50])
        start_price = round(normal_price * (1 - initial_discount), -2)
        min_price = round(normal_price * 0.35, -2) # Batas bawah 35% dari normal

        # Distribusi waktu: 80% Masih Berlangsung (H-3 s/d H-40), 10% Terjual (Sold), 10% Dialihkan (Diverted)
        rand_status_selector = random.random()
        if rand_status_selector < 0.10:
            status = "diverted"
            # Sudah kedaluwarsa beberapa hari lalu
            expiry_date = (now - timedelta(days=random.randint(1, 5))).date()
            auction_start = now - timedelta(days=14)
            auction_end = now - timedelta(days=1)
        elif rand_status_selector < 0.25:
            status = "sold"
            expiry_date = (now + timedelta(days=random.randint(5, 20))).date()
            auction_start = now - timedelta(days=2)
            auction_end = now + timedelta(days=5)
        else:
            status = "active"
            # Tanggal kedaluwarsa bervariasi dari 3 hari lagi sampai 45 hari lagi
            expiry_date = (now + timedelta(days=random.randint(3, 45))).date()
            auction_start = now - timedelta(hours=random.randint(1, 24))
            auction_end = now + timedelta(days=random.randint(3, 10))

        listing = Listing(
            product_id=chosen_product.id,
            seller_id=chosen_seller.id,
            batch_number=f"LOT-{seller_city['city'][:3].upper()}-{random.randint(10000, 99999)}",
            qty=random.randint(5, 80),
            normal_price=normal_price,
            start_price=start_price,
            min_price=min_price,
            drop_interval_minutes=random.choice([30, 60, 120]),
            drop_percentage=random.choice([2.00, 2.50, 3.00, 5.00]),
            expiry_date=expiry_date,
            auction_start_at=auction_start,
            auction_end_at=auction_end,
            status=status,
            created_at=auction_start
        )
        listings_list.append(listing)

    # Batch insert 1000 listings
    db.add_all(listings_list)
    db.flush()

    # --------------------------------------------------------------------------
    # LEVEL 4: TRANSAKSI (ORDERS), AI MATCH LOGS (OFFERS) & DONATIONS (ESG)
    # --------------------------------------------------------------------------
    print("🤝 [5/6] Mengenerate Transaksi Orders, AI Matching Offers, dan Donasi ESG...")
    orders = []
    donations = []
    offers = []

    diverted_count = 0
    for l in listings_list:
        # Jika status sold -> buat order
        if l.status == "sold":
            buyer = random.choice(buyers_list)
            qty_ordered = random.randint(1, l.qty)
            unit_price = l.start_price
            order = Order(
                listing_id=l.id,
                buyer_id=buyer.id,
                qty=qty_ordered,
                final_unit_price=unit_price,
                total_price=qty_ordered * unit_price,
                status=random.choice(["paid", "picked_up", "completed"]),
                created_at=l.created_at + timedelta(hours=4)
            )
            orders.append(order)

        # Jika status diverted -> buat sertifikat donasi ESG
        elif l.status == "diverted":
            diverted_count += 1
            offtaker = random.choice(offtakers)
            grade = random.choice(["A", "B", "C"])
            carbon_saved = round(l.qty * random.uniform(1.8, 3.2), 2)
            cert_no = f"ESG-ID-2026-{1000 + diverted_count:05d}"
            tx_hash = f"0x{''.join(random.choices('0123456789abcdef', k=64))}"
            
            donation = Donation(
                listing_id=l.id,
                offtaker_id=offtaker.id,
                grade=grade,
                qty_diverted=l.qty,
                carbon_saved_kg=carbon_saved,
                certificate_no=cert_no,
                certificate_tx_hash=tx_hash,
                block_number=random.randint(5000000, 6000000),
                created_at=l.auction_end_at + timedelta(hours=2)
            )
            donations.append(donation)

        # Buat sampel AI match offers untuk sebagian listing aktif
        if l.status == "active" and random.random() < 0.35:
            buyer = random.choice(buyers_list)
            days_left = (l.expiry_date - now.date()).days
            offer = Offer(
                listing_id=l.id,
                buyer_id=buyer.id,
                match_score=round(random.uniform(0.720, 0.985), 3),
                distance_km=round(random.uniform(1.2, 14.8), 2),
                days_to_expiry=max(1, days_left),
                offered_discount_pct=round(((l.normal_price - l.start_price) / l.normal_price) * 100, 2),
                status=random.choice(["sent", "opened", "accepted"]),
                sent_at=now - timedelta(hours=random.randint(1, 12))
            )
            offers.append(offer)

    db.add_all(orders)
    db.add_all(donations)
    db.add_all(offers)
    db.flush()

    # --------------------------------------------------------------------------
    # LEVEL 5: FEEDBACK KULIAH PAM (Kriteria Wajib)
    # --------------------------------------------------------------------------
    print("📝 [6/6] Menyimpan Saran & Kesan Mahasiswa untuk Matkul PAM...")
    feedback_samples = [
        ("Materi arsitektur mobile dan database lokal-online sangat aplikatif untuk studi kasus dunia nyata.", "Diharapkan modul integrasi sensor kompas dan kamera diberikan studi kasus lebih banyak."),
        ("Proyek Recovera ini sangat membuka wawasan mengenai penanganan limbah makanan B2B menggunakan Flutter dan PostgreSQL.", "Waktu asistensi mingguan bisa diperpanjang agar kelompok bisa berdiskusi lebih leluasa."),
        ("Sangat menantang! Konsep Dutch Auction dengan konversi multi-zona waktu WIB/WITA/WIT/London melatih pemahaman logika backend & frontend yang solid.", "Semoga server atau koneksi demo disiapkan cadangan offline untuk presentasi akhir."),
        ("Penggunaan Supabase dan SQLite offline-first sangat cocok untuk kondisi jaringan di Indonesia.", "Tutorial deployment ke testnet blockchain untuk sertifikat ESG sangat menarik."),
    ]
    for i, (kesan, saran) in enumerate(feedback_samples):
        cf = CourseFeedback(
            user_id=i + 1,
            kesan=kesan,
            saran=saran,
            submitted_at=now - timedelta(days=random.randint(1, 10))
        )
        db.add(cf)

    # Commit seluruh data sekaligus ke Supabase
    print("💾 Melakukan commit seluruh transaksi ke PostgreSQL Supabase...")
    db.commit()
    print("==================================================================")
    print("🎉 SEEDER BERHASIL DILAKSANAKAN DENGAN SUKSES!")
    print(f"📊 Ringkasan Data Tersimpan:")
    print(f"   • Users: {50 + 100} Akun (50 Seller, 100 Buyer)")
    print(f"   • Master Produk Pangan: {len(products)} Produk Asli Indonesia")
    print(f"   • Distributor Sellers: 50 Gudang di 15 Kota Indonesia")
    print(f"   • Pembeli UMKM: 100 Usaha Kuliner, Katering, & Bakery")
    print(f"   • Listings Lelang: {len(listings_list)} Baris Batch Pangan!")
    print(f"   • Transaksi Orders: {len(orders)} Pesanan Berhasil")
    print(f"   • Sertifikat Donasi ESG: {len(donations)} Sertifikat Terbit")
    print(f"   • AI Offer Logs: {len(offers)} Log Rekomendasi")
    print("==================================================================")

if __name__ == "__main__":
    try:
        seed_database()
    except Exception as e:
        db.rollback()
        print(f"❌ Terjadi kesalahan saat seeding: {e}")
    finally:
        db.close()
