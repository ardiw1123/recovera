import pytest
from app.models.donation import Donation, Offtaker
from app.models.listing import Listing
from app.models.product import Product
from app.models.user import Seller, User
from app.services.donation_service import (
    divert_listing_to_donation,
    get_current_exchange_rates,
    get_donation_certificate,
    verify_blockchain_hash,
)
from datetime import date, datetime, timezone


def test_rates_endpoint(client):
    res = client.get("/rates")
    assert res.status_code == 200
    data = res.json()["data"]
    assert data["base_currency"] == "IDR"
    assert "USD" in data["rates"]
    assert "EUR" in data["rates"]
    assert "GBP" in data["rates"]
    assert data["rates"]["USD"] > 0


def test_blockchain_verify_confirmed_tx(client):
    confirmed_tx = "0x24c5755a91a54cb4e0f273a5e7c1534cc635e16400bec4aa019a1fb118aabb5c"
    res = client.get(f"/blockchain/verify/{confirmed_tx}")
    assert res.status_code == 200
    data = res.json()["data"]
    assert data["verified"] is True
    assert data["status"] == "Confirmed"
    assert data["block_number"] == 27996026
    assert data["network"] == "BOT Chain Testnet"
    assert data["contract_address"] == "0x485D903159eac9D30E9EadC7abdd4Af18dc5c859"
    assert "scan.bohr.life" in data["block_explorer_url"]
    assert data["certificate_hash_on_chain"] is not None


def test_blockchain_verify_nonexistent_tx(client):
    fake_tx = "0x0000000000000000000000000000000000000000000000000000000000000000"
    res = client.get(f"/blockchain/verify/{fake_tx}")
    assert res.status_code == 200
    data = res.json()["data"]
    assert data["verified"] is False


def test_donation_certificate_details(client, db_session):
    offtaker = db_session.query(Offtaker).first()
    if not offtaker:
        offtaker = Offtaker(
            name="Bank Pangan Jakarta",
            type="foodbank",
            lat=-6.2,
            lng=106.8,
            contact="+628123456",
        )
        db_session.add(offtaker)
        db_session.flush()

    seller_user = User(
        email="cert_seller@recovera.id",
        password_hash="fakehash",
        role="seller",
        name="Cert Seller",
    )
    db_session.add(seller_user)
    db_session.flush()

    seller = Seller(
        user_id=seller_user.id,
        company_name="Cert Bakery",
        address="Jl. Roti No 1",
        warehouse_lat=-6.18,
        warehouse_lng=106.82,
        city="Jakarta",
    )
    db_session.add(seller)
    db_session.flush()

    product = Product(
        sku="SKU-ROTI-001",
        name="Roti Tawar Gandum",
        category="Bakery",
        storage_type="ambient",
        default_unit="pack",
        barcode="8991234567890",
    )
    db_session.add(product)
    db_session.flush()

    listing = Listing(
        product_id=product.id,
        seller_id=seller.id,
        batch_number="BATCH-CERT-01",
        qty=50,
        normal_price=25000,
        start_price=20000,
        min_price=15000,
        drop_interval_minutes=60,
        drop_percentage=2.5,
        expiry_date=date.today(),
        auction_start_at=datetime.now(timezone.utc),
        auction_end_at=datetime.now(timezone.utc),
        status="diverted",
    )
    db_session.add(listing)
    db_session.flush()

    donation = Donation(
        listing_id=listing.id,
        offtaker_id=offtaker.id,
        grade="A",
        qty_diverted=50,
        carbon_saved_kg=125.0,
        certificate_no="ESG-ID-2026-CERT99",
        certificate_tx_hash="0x24c5755a91a54cb4e0f273a5e7c1534cc635e16400bec4aa019a1fb118aabb5c",
        block_number=27996026,
    )
    db_session.add(donation)
    db_session.commit()

    res = client.get(f"/donations/{donation.id}/certificate")
    assert res.status_code == 200
    data = res.json()["data"]
    assert data["certificate_no"] == "ESG-ID-2026-CERT99"
    assert data["product_name"] == "Roti Tawar Gandum"
    assert data["grade"] == "A"
    assert data["carbon_saved_kg"] == 125.0
    assert "WIB" in data["issued_at_wib"]
    assert data["blockchain_status"] == "Tercatat"
    assert data["explorer_url"] is not None
    assert "scan.bohr.life" in data["explorer_url"]


def test_donations_my_endpoint(client, db_session):
    # Register a new seller
    reg_res = client.post("/auth/register", json={
        "email": "my_esg_seller@recovera.id",
        "password": "Password123!",
        "role": "seller",
        "name": "ESG Seller Owner",
        "company_name": "PT Hijau Lestari",
        "phone": "+62811999888",
        "address": "Jl. Lingkungan No. 5",
        "warehouse_lat": -6.18,
        "warehouse_lng": 106.82,
        "city": "Jakarta",
    })
    assert reg_res.status_code == 201
    token = reg_res.json()["data"]["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    res = client.get("/donations/my", headers=headers)
    assert res.status_code == 200
    data = res.json()["data"]
    assert "items" in data
    assert "total_certificates" in data
    assert "total_carbon_saved_kg" in data
    assert isinstance(data["items"], list)
