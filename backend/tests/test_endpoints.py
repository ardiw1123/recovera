import io
from datetime import date, datetime, timedelta, timezone
from app.models.donation import Donation


def test_health_check(client):
    response = client.get("/health")
    assert response.status_code == 200
    json_data = response.json()
    assert json_data["success"] is True
    assert "data" in json_data
    assert json_data["data"]["status"] == "healthy"


def test_error_envelope_format_on_unauthorized(client):
    response = client.get("/profile")
    assert response.status_code == 401
    json_data = response.json()
    assert json_data["success"] is False
    assert "error" in json_data
    assert json_data["error"]["code"] == "UNAUTHORIZED"
    assert "message" in json_data["error"]


def test_auth_and_profile_flow(client):
    # 1. Register Seller
    seller_payload = {
        "email": "seller@recovera.id",
        "password": "Password123!",
        "role": "seller",
        "name": "Budi Distributor",
        "company_name": "PT Pangan Mandiri",
        "phone": "+628111222333",
        "address": "Jl. Industri No. 10",
        "warehouse_lat": -6.2088,
        "warehouse_lng": 106.8456,
        "city": "Jakarta",
    }
    res = client.post("/auth/register", json=seller_payload)
    assert res.status_code == 201
    body = res.json()
    assert body["success"] is True
    seller_token = body["data"]["access_token"]
    seller_refresh = body["data"]["refresh_token"]

    # 2. Register Buyer
    buyer_payload = {
        "email": "buyer@recovera.id",
        "password": "Password123!",
        "role": "buyer",
        "name": "Siti Bakery",
        "phone": "+628777888999",
        "business_type": "bakery",
        "address": "Jl. Kuliner No. 5",
        "base_lat": -6.2100,
        "base_lng": 106.8400,
        "pref_categories": ["Flour & Grain", "Dairy"],
    }
    res_b = client.post("/auth/register", json=buyer_payload)
    assert res_b.status_code == 201
    buyer_token = res_b.json()["data"]["access_token"]

    # 3. Login
    login_res = client.post("/auth/login", json={"email": "seller@recovera.id", "password": "Password123!"})
    assert login_res.status_code == 200
    assert login_res.json()["success"] is True

    # 4. Token Refresh
    refresh_res = client.post("/auth/refresh", json={"refresh_token": seller_refresh})
    assert refresh_res.status_code == 200
    assert refresh_res.json()["success"] is True
    new_token = refresh_res.json()["data"]["access_token"]
    seller_refresh = refresh_res.json()["data"]["refresh_token"]

    # 5. Get and Update Profile
    headers = {"Authorization": f"Bearer {new_token}"}
    prof_res = client.get("/profile", headers=headers)
    assert prof_res.status_code == 200
    prof_data = prof_res.json()["data"]
    assert prof_data["email"] == "seller@recovera.id"
    assert prof_data["seller"]["company_name"] == "PT Pangan Mandiri"

    patch_res = client.patch("/profile", json={"name": "Budi Santoso"}, headers=headers)
    assert patch_res.status_code == 200
    assert patch_res.json()["data"]["name"] == "Budi Santoso"

    # 6. Logout
    logout_res = client.post(
        "/auth/logout", headers=headers, json={"refresh_token": seller_refresh},
    )
    assert logout_res.status_code == 200
    assert logout_res.json()["success"] is True


def test_product_and_listing_and_order_flow(client, db_session):
    # Setup seller and buyer
    s_res = client.post("/auth/register", json={
        "email": "distributor1@recovera.id",
        "password": "Password123!",
        "role": "seller",
        "name": "Pak Hendra",
        "company_name": "CV Berkah Jaya",
        "address": "Gudang Berkah",
        "warehouse_lat": -6.2200,
        "warehouse_lng": 106.8300,
        "city": "Jakarta Selatan",
    })
    seller_token = s_res.json()["data"]["access_token"]
    s_headers = {"Authorization": f"Bearer {seller_token}"}

    b_res = client.post("/auth/register", json={
        "email": "resto1@recovera.id",
        "password": "Password123!",
        "role": "buyer",
        "name": "Warung Enak",
        "business_type": "resto",
        "address": "Jl. Hang Tuah",
        "base_lat": -6.2250,
        "base_lng": 106.8350,
    })
    buyer_token = b_res.json()["data"]["access_token"]
    b_headers = {"Authorization": f"Bearer {buyer_token}"}

    # 1. Create master product
    prod_res = client.post("/products", json={
        "sku": "PROD-MILK-001",
        "name": "Susu UHT Fresh 1L",
        "category": "Dairy",
        "storage_type": "chilled",
        "default_unit": "karton",
        "brand": "Ultra Milk",
    }, headers=s_headers)
    assert prod_res.status_code == 201
    prod_id = prod_res.json()["data"]["id"]

    # 2. Create listing
    exp_date = (date.today() + timedelta(days=20)).isoformat()
    list_res = client.post("/listings", json={
        "product_id": prod_id,
        "batch_number": "LOT-2026-X1",
        "qty": 50,
        "normal_price": 200000.0,
        "min_price": 90000.0,
        "drop_interval_minutes": 60,
        "drop_percentage": 2.50,
        "expiry_date": exp_date,
    }, headers=s_headers)
    assert list_res.status_code == 201
    listing_id = list_res.json()["data"]["id"]
    current_price = list_res.json()["data"]["current_price"]
    assert current_price >= 90000.0

    # 3. Browse listings with filters
    search_res = client.get(
        f"/listings?category=Dairy&search=Susu&lat=-6.2250&lng=106.8350&radius_km=15&sort=nearest",
        headers=b_headers,
    )
    assert search_res.status_code == 200
    items = search_res.json()["data"]
    assert len(items) >= 1
    assert items[0]["distance_km"] is not None
    assert items[0]["auction_end_timezones"]["wib"] is not None

    # 4. Get my listings (seller)
    my_res = client.get("/listings/my", headers=s_headers)
    assert my_res.status_code == 200
    assert len(my_res.json()["data"]) >= 1

    # 5. Get listing detail
    detail_res = client.get(f"/listings/{listing_id}")
    assert detail_res.status_code == 200
    assert detail_res.json()["data"]["id"] == listing_id

    # 6. Execute Buy Now
    buy_res = client.post(
        f"/listings/{listing_id}/buy",
        json={"qty": 10, "biometric_verified": True},
        headers=b_headers,
    )
    assert buy_res.status_code == 201
    order_id = buy_res.json()["data"]["id"]
    assert buy_res.json()["data"]["status"] == "paid"

    # Check listing stock decremented to 40
    refreshed_listing = client.get(f"/listings/{listing_id}").json()["data"]
    assert refreshed_listing["qty"] == 40

    # 7. Orders endpoints
    orders_res = client.get("/orders", headers=b_headers)
    assert orders_res.status_code == 200
    assert len(orders_res.json()["data"]) >= 1

    order_detail = client.get(f"/orders/{order_id}", headers=b_headers)
    assert order_detail.status_code == 200
    assert order_detail.json()["data"]["id"] == order_id

    # 8. Update order status
    patch_order = client.patch(
        f"/orders/{order_id}/status",
        json={"status": "picked_up"},
        headers=b_headers,
    )
    assert patch_order.status_code == 200
    assert patch_order.json()["data"]["status"] == "picked_up"


def test_ai_endpoints(client):
    # Setup seller token
    s_res = client.post("/auth/register", json={
        "email": "aiseller@recovera.id",
        "password": "Password123!",
        "role": "seller",
        "name": "AI Seller",
        "company_name": "AI Mart",
    })
    token = s_res.json()["data"]["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # 1. Invoice OCR
    fake_file = io.BytesIO(b"dummy invoice content for OCR test")
    ocr_res = client.post(
        "/ai/invoice",
        files={"file": ("invoice.pdf", fake_file, "application/pdf")},
        headers=headers,
    )
    assert ocr_res.status_code == 200
    ocr_data = ocr_res.json()
    assert ocr_data["success"] is True
    assert len(ocr_data["data"]["parsed_items"]) >= 1

    # 2. Price Advice
    exp_str = (date.today() + timedelta(days=25)).isoformat()
    advice_res = client.post(
        "/ai/price-advice",
        json={
            "normal_price": 200000.0,
            "expiry_date": exp_str,
            "category": "Dairy",
            "qty": 50,
        },
        headers=headers,
    )
    assert advice_res.status_code == 200
    advice_data = advice_res.json()["data"]
    assert advice_data["discount_pct"] in [40.0, 50.0]
    assert advice_data["suggested_price"] in [120000.0, 100000.0]
    assert advice_data["source"] in ["ml", "rule"]
    assert "rationale" in advice_data


def test_seller_inventory_draft_review_and_publish(client):
    seller_res = client.post("/auth/register", json={
        "email": "inventory-seller@recovera.id", "password": "Password123!",
        "role": "seller", "name": "Inventory Seller", "company_name": "Fresh Stock",
    })
    seller_headers = {"Authorization": f"Bearer {seller_res.json()['data']['access_token']}"}
    buyer_res = client.post("/auth/register", json={
        "email": "inventory-buyer@recovera.id", "password": "Password123!",
        "role": "buyer", "name": "Inventory Buyer",
    })
    buyer_headers = {"Authorization": f"Bearer {buyer_res.json()['data']['access_token']}"}
    payload = {
        "sku": "INV-TEST-001", "name": "Fresh Milk", "category": "Dairy",
        "storage_type": "chilled", "default_unit": "carton",
        "image_url": "https://images.example.test/fresh-milk.jpg",
        "batch_number": "MILK-LOT-01", "qty": 12, "normal_price": 100000,
        "min_price": 10000, "expiry_date": (date.today() + timedelta(days=40)).isoformat(),
    }

    denied = client.post("/listings/seller/inventory/drafts", json=payload, headers=buyer_headers)
    assert denied.status_code == 403

    created = client.post("/listings/seller/inventory/drafts", json=payload, headers=seller_headers)
    assert created.status_code == 201
    draft = created.json()["data"]
    listing_id = draft["listing"]["id"]
    assert draft["validation"]["valid"] is True
    assert draft["listing"]["product"]["name"] == "Fresh Milk"
    assert draft["listing"]["product"]["image_url"] == payload["image_url"]

    inventory = client.get("/listings/seller/inventory", headers=seller_headers)
    assert inventory.status_code == 200
    assert inventory.json()["data"][0]["status"] == "draft"

    recommendation = client.post(
        f"/listings/seller/inventory/{listing_id}/recommendation", headers=seller_headers,
    )
    assert recommendation.status_code == 200
    # Move the start price outside the advice range and require acknowledgement on publish.
    edit = client.patch(
        f"/listings/seller/inventory/{listing_id}",
        json={"start_price": 90000}, headers=seller_headers,
    )
    assert edit.status_code == 200
    warned = client.post(
        f"/listings/seller/inventory/{listing_id}/publish", json={}, headers=seller_headers,
    )
    assert warned.status_code == 409
    published = client.post(
        f"/listings/seller/inventory/{listing_id}/publish",
        json={"acknowledge_price_warning": True}, headers=seller_headers,
    )
    assert published.status_code == 200
    assert published.json()["data"]["status"] == "active"


def test_auxiliary_endpoints(client, db_session):
    # 1. Rates
    rates_res = client.get("/rates")
    assert rates_res.status_code == 200
    rates_data = rates_res.json()["data"]
    assert rates_data["base_currency"] == "IDR"
    assert "USD" in rates_data["rates"]

    # 2. Blockchain verify
    bc_res = client.get("/blockchain/verify/0xabc123456789def")
    assert bc_res.status_code == 200
    assert bc_res.json()["data"]["verified"] is True
    assert bc_res.json()["data"]["network"] == "BOT Chain Testnet"

    # 3. Feedback and Notifications & Devices
    u_res = client.post("/auth/register", json={
        "email": "useraux@recovera.id",
        "password": "Password123!",
        "role": "buyer",
        "name": "Student User",
    })
    token = u_res.json()["data"]["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # Feedback
    fb_res = client.post(
        "/feedback",
        json={
            "kesan": "Materi praktikum PAM sangat aplikatif dan menantang.",
            "saran": "Pertahankan penggunaan skema industri seperti FastAPI dan Docker.",
        },
        headers=headers,
    )
    assert fb_res.status_code == 201
    assert fb_res.json()["data"]["kesan"] != ""

    # Devices
    dev_res = client.post(
        "/devices",
        json={"fcm_token": "fcm-device-token-sample-123"},
        headers=headers,
    )
    assert dev_res.status_code == 200
    assert dev_res.json()["success"] is True

    # Notifications inbox
    notif_res = client.get("/notifications", headers=headers)
    assert notif_res.status_code == 200
    assert isinstance(notif_res.json()["data"], list)

    # 4. Donation Certificate
    donation = Donation(
        listing_id=1,
        offtaker_id=1,
        grade="A",
        qty_diverted=20,
        carbon_saved_kg=52.5,
        certificate_no="ESG-2026-0001",
        certificate_tx_hash="0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
        block_number=1001,
    )
    db_session.add(donation)
    db_session.commit()

    cert_res = client.get(f"/donations/{donation.id}/certificate")
    assert cert_res.status_code == 200
    cert_data = cert_res.json()["data"]
    assert cert_data["certificate_no"] == "ESG-2026-0001"
    assert cert_data["monetary_value"]["idr"] > 0
    assert "london" in cert_data["issued_at_london"].lower() or "gmt" in cert_data["issued_at_london"].lower() or "bst" in cert_data["issued_at_london"].lower()

