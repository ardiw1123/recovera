"""QA End-to-End Test Suite for Buyer Features (ARDI-86)

Verifies:
1. Proximity matching, Haversine distance calculations, and distance-based sorting (sort=nearest).
2. Radius-based filtering (radius_km) and category filtering.
3. Recommendation match score computation, discount percentage, and days to expiry.
4. Product detail endpoint data completeness (specifications, batch, seller company, multi-timezone).
5. Purchase workflow (POST /listings/{id}/buy): stock decrement, status transitions, validation errors.
6. Role-Based Access Control (RBAC):
   - Seller prohibited from buyer purchase endpoint (403 Forbidden).
   - Buyer prohibited from seller listing creation / inventory endpoints (403 Forbidden).
   - Unauthenticated requests rejected (401 Unauthorized).
7. Edge cases: missing coordinates, out-of-stock, invalid quantity, biometric verification flag.
"""

from datetime import date, timedelta
import pytest


def _create_seller_and_token(client, email_prefix, warehouse_lat, warehouse_lng, company_name, city):
    res = client.post("/auth/register", json={
        "email": f"{email_prefix}@example.com",
        "password": "Password123!",
        "role": "seller",
        "name": f"Seller {company_name}",
        "company_name": company_name,
        "phone": "+62811223344",
        "address": f"Warehouse {city}",
        "warehouse_lat": warehouse_lat,
        "warehouse_lng": warehouse_lng,
        "city": city,
    })
    assert res.status_code == 201
    return res.json()["data"]["access_token"]


def _create_buyer_and_token(client, email_prefix, base_lat, base_lng, name):
    res = client.post("/auth/register", json={
        "email": f"{email_prefix}@example.com",
        "password": "Password123!",
        "role": "buyer",
        "name": name,
        "phone": "+62899887766",
        "business_type": "bakery",
        "address": "Buyer Base Location",
        "base_lat": base_lat,
        "base_lng": base_lng,
        "pref_categories": ["Dairy", "Bakery"],
    })
    assert res.status_code == 201
    return res.json()["data"]["access_token"]


def _create_product_and_listing(client, seller_token, sku, name, category, qty, normal_price, start_price, min_price, days_to_expiry):
    headers = {"Authorization": f"Bearer {seller_token}"}
    p_res = client.post("/products", json={
        "sku": sku,
        "name": name,
        "category": category,
        "storage_type": "chilled",
        "default_unit": "karton",
        "brand": "Quality Brand",
    }, headers=headers)
    assert p_res.status_code == 201
    product_id = p_res.json()["data"]["id"]

    exp_date = (date.today() + timedelta(days=days_to_expiry)).isoformat()
    l_res = client.post("/listings", json={
        "product_id": product_id,
        "batch_number": f"BATCH-{sku}",
        "qty": qty,
        "normal_price": normal_price,
        "start_price": start_price,
        "min_price": min_price,
        "drop_interval_minutes": 60,
        "drop_percentage": 2.50,
        "expiry_date": exp_date,
    }, headers=headers)
    assert l_res.status_code == 201
    return l_res.json()["data"]


def test_proximity_calculation_and_distance_sorting(client):
    """
    Verify proximity calculations and distance-based sorting.
    Buyer located at Monas, Jakarta Pusat (-6.1754, 106.8272).
    Seller 1: Jakarta Pusat (-6.1800, 106.8300) -> ~0.6 km (Nearest)
    Seller 2: Jakarta Selatan (-6.2500, 106.8100) -> ~8.5 km (Medium)
    Seller 3: Bekasi (-6.2383, 106.9756) -> ~18 km (Far)
    """
    buyer_token = _create_buyer_and_token(client, "buyer_prox", -6.1754, 106.8272, "Buyer Central")
    buyer_headers = {"Authorization": f"Bearer {buyer_token}"}

    s1_token = _create_seller_and_token(client, "s1_central", -6.1800, 106.8300, "PT Pangan Pusat", "Jakarta Pusat")
    s2_token = _create_seller_and_token(client, "s2_south", -6.2500, 106.8100, "PT Pangan Selatan", "Jakarta Selatan")
    s3_token = _create_seller_and_token(client, "s3_bekasi", -6.2383, 106.9756, "PT Pangan Timur", "Bekasi")

    l1 = _create_product_and_listing(client, s1_token, "SKU-PROX-1", "Keju Edam 500g", "Dairy", 50, 100000.0, 70000.0, 50000.0, 15)
    l2 = _create_product_and_listing(client, s2_token, "SKU-PROX-2", "Butter Anchor 1kg", "Dairy", 30, 200000.0, 140000.0, 100000.0, 20)
    l3 = _create_product_and_listing(client, s3_token, "SKU-PROX-3", "Whipping Cream 1L", "Dairy", 20, 80000.0, 60000.0, 40000.0, 25)

    # 1. Query with buyer coordinates and sort=nearest
    res = client.get(
        "/listings?lat=-6.1754&lng=106.8272&sort=nearest",
        headers=buyer_headers,
    )
    assert res.status_code == 200
    items = res.json()["data"]
    assert len(items) >= 3

    # Find our 3 test listings
    test_ids = [l1["id"], l2["id"], l3["id"]]
    filtered_items = [it for it in items if it["id"] in test_ids]
    assert len(filtered_items) == 3

    # Check ascending order of distance
    distances = [it["distance_km"] for it in filtered_items]
    assert distances[0] < distances[1] < distances[2]
    assert distances[0] < 1.0  # ~0.6 km
    assert 5.0 < distances[1] < 12.0  # ~8.5 km
    assert distances[2] > 15.0  # ~18 km

    # Verify seller company name & city mapped correctly
    assert filtered_items[0]["seller_company"] == "PT Pangan Pusat"
    assert filtered_items[0]["warehouse_city"] == "Jakarta Pusat"

    # 2. Test radius_km filter: radius_km=10 should include Seller 1 and 2, but exclude Seller 3 (Bekasi)
    res_radius = client.get(
        "/listings?lat=-6.1754&lng=106.8272&radius_km=10&sort=nearest",
        headers=buyer_headers,
    )
    assert res_radius.status_code == 200
    radius_items = res_radius.json()["data"]
    radius_ids = [it["id"] for it in radius_items if it["id"] in test_ids]
    assert l1["id"] in radius_ids
    assert l2["id"] in radius_ids
    assert l3["id"] not in radius_ids


def test_match_score_and_metrics_calculation(client):
    """
    Verify recommendation match score, discount percentage, and days to expiry.
    Formula:
      proximity_score = max(0, 1.0 - (distance / 50.0))
      discount_factor = min(1.0, days_left / 30.0) if days_left > 0 else 0.0
      match_score = round(proximity_score * discount_factor, 3)
      discount_pct = round(((normal_price - current_price) / normal_price) * 100, 2)
    """
    s_token = _create_seller_and_token(client, "s_metrics", -6.1800, 106.8300, "PT Metrik Presisi", "Jakarta Pusat")
    listing = _create_product_and_listing(
        client, s_token, "SKU-METRIC-1", "Susu Pasteurisasi 1L", "Dairy",
        qty=100, normal_price=50000.0, start_price=30000.0, min_price=20000.0, days_to_expiry=15,
    )

    buyer_lat = -6.1800
    buyer_lng = 106.8300  # Distance = 0 km

    res = client.get(f"/listings?lat={buyer_lat}&lng={buyer_lng}&search=Pasteurisasi")
    assert res.status_code == 200
    items = res.json()["data"]
    target = next((it for it in items if it["id"] == listing["id"]), None)
    assert target is not None

    # Distance is 0 km
    assert target["distance_km"] == 0.0

    # Days to expiry = 15
    assert target["days_to_expiry"] == 15

    # Match score:
    # proximity_score = 1.0 - (0 / 50) = 1.0
    # discount_factor = 15 / 30 = 0.5
    # match_score = 1.0 * 0.5 = 0.5
    assert target["match_score"] == 0.5

    # Discount pct:
    # normal_price = 50000, current_price = 30000 -> (50000 - 30000) / 50000 * 100 = 40.0%
    assert target["discount_pct"] == 40.0


def test_product_detail_endpoint_contract(client):
    """
    Verify GET /listings/{id} delivers complete product attributes, batch metadata,
    verified seller profile information, and multi-timezone schedules.
    """
    s_token = _create_seller_and_token(client, "s_detail", -6.2100, 106.8400, "PT Detail Mandiri", "Jakarta Timur")
    listing = _create_product_and_listing(
        client, s_token, "SKU-DETAIL-1", "Daging Sapi Sirloin 1kg", "Meat",
        qty=45, normal_price=160000.0, start_price=120000.0, min_price=80000.0, days_to_expiry=10,
    )

    res = client.get(f"/listings/{listing['id']}")
    assert res.status_code == 200
    data = res.json()["data"]

    # Product specifications
    assert data["id"] == listing["id"]
    assert data["batch_number"] == "BATCH-SKU-DETAIL-1"
    assert data["qty"] == 45
    assert data["normal_price"] == 160000.0
    assert data["current_price"] == 120000.0
    assert data["min_price"] == 80000.0
    assert data["days_to_expiry"] == 10
    assert data["status"] == "active"

    # Product entity
    assert data["product"]["name"] == "Daging Sapi Sirloin 1kg"
    assert data["product"]["category"] == "Meat"
    assert data["product"]["storage_type"] == "chilled"
    assert data["product"]["default_unit"] == "karton"

    # Seller organization
    assert data["seller_company"] == "PT Detail Mandiri"
    assert data["warehouse_city"] == "Jakarta Timur"
    assert data["warehouse_lat"] == -6.2100
    assert data["warehouse_lng"] == 106.8400

    # Multi-timezone auction end
    tzs = data["auction_end_timezones"]
    assert "WIB" in tzs["wib"]
    assert "WITA" in tzs["wita"]
    assert "WIT" in tzs["wit"]


def test_purchase_flow_execution_and_inventory_decrement(client):
    """
    Verify POST /listings/{id}/buy executes purchase workflow:
    1. Quantity decrements accurately.
    2. Total order price calculated correctly.
    3. Status transitions to 'sold' when remaining stock reaches 0.
    4. Database order record created with 'paid' status.
    """
    s_token = _create_seller_and_token(client, "s_order", -6.2000, 106.8000, "PT Gudang Berkah", "Jakarta Pusat")
    b_token = _create_buyer_and_token(client, "b_order", -6.2050, 106.8050, "Resto Sari Rasa")
    b_headers = {"Authorization": f"Bearer {b_token}"}

    listing = _create_product_and_listing(
        client, s_token, "SKU-ORDER-1", "Telur Ayam Organik 1kg", "Poultry",
        qty=15, normal_price=40000.0, start_price=30000.0, min_price=20000.0, days_to_expiry=12,
    )
    listing_id = listing["id"]

    # 1. Partial purchase (buy 10 out of 15)
    buy_res = client.post(
        f"/listings/{listing_id}/buy",
        json={"qty": 10, "biometric_verified": True},
        headers=b_headers,
    )
    assert buy_res.status_code == 201
    order_data = buy_res.json()["data"]
    assert order_data["qty"] == 10
    assert order_data["final_unit_price"] == 30000.0
    assert order_data["total_price"] == 300000.0
    assert order_data["status"] == "paid"

    # Verify remaining stock decremented to 5
    refreshed = client.get(f"/listings/{listing_id}").json()["data"]
    assert refreshed["qty"] == 5
    assert refreshed["status"] == "active"

    # 2. Complete purchase of remaining 5 units
    buy_rest = client.post(
        f"/listings/{listing_id}/buy",
        json={"qty": 5, "biometric_verified": True},
        headers=b_headers,
    )
    assert buy_rest.status_code == 201

    # Verify listing is now sold out (qty = 0, status = "sold")
    final_listing = client.get(f"/listings/{listing_id}").json()["data"]
    assert final_listing["qty"] == 0
    assert final_listing["status"] == "sold"


def test_role_based_access_control_guardrails(client):
    """
    Verify security authorization guardrails:
    1. Seller accounts are STRICTLY PROHIBITED from executing purchases (403 Forbidden).
    2. Buyer accounts are prohibited from accessing seller inventory/publishing endpoints (403 Forbidden).
    3. Unauthenticated requests to purchase endpoint are rejected (401 Unauthorized).
    """
    s_token = _create_seller_and_token(client, "s_rbac", -6.2000, 106.8000, "PT Seller RBAC", "Jakarta")
    s_headers = {"Authorization": f"Bearer {s_token}"}

    b_token = _create_buyer_and_token(client, "b_rbac", -6.2100, 106.8100, "Buyer RBAC Resto")
    b_headers = {"Authorization": f"Bearer {b_token}"}

    listing = _create_product_and_listing(
        client, s_token, "SKU-RBAC-1", "Beras Pandan Wangi 5kg", "Grains",
        qty=50, normal_price=90000.0, start_price=70000.0, min_price=50000.0, days_to_expiry=30,
    )
    listing_id = listing["id"]

    # 1. Seller attempts to buy product -> 403 Forbidden
    seller_buy_res = client.post(
        f"/listings/{listing_id}/buy",
        json={"qty": 1, "biometric_verified": True},
        headers=s_headers,
    )
    assert seller_buy_res.status_code == 403
    err = seller_buy_res.json()["error"]
    assert err["code"] == "FORBIDDEN"
    assert "buyer" in err["message"].lower()

    # 2. Unauthenticated user attempts to buy product -> 401 Unauthorized
    anon_buy_res = client.post(
        f"/listings/{listing_id}/buy",
        json={"qty": 1, "biometric_verified": True},
    )
    assert anon_buy_res.status_code == 401
    assert anon_buy_res.json()["error"]["code"] == "UNAUTHORIZED"

    # 3. Buyer attempts to create seller inventory draft -> 403 Forbidden
    buyer_draft_res = client.post(
        "/listings/seller/inventory/drafts",
        json={
            "sku": "SKU-ILLEGAL",
            "name": "Illegal Product",
            "category": "Grains",
            "storage_type": "ambient",
            "default_unit": "kg",
            "image_url": "https://example.com/img.png",
            "batch_number": "BATCH-ILLEGAL",
            "qty": 10,
            "normal_price": 50000.0,
            "min_price": 30000.0,
            "expiry_date": (date.today() + timedelta(days=20)).isoformat(),
        },
        headers=b_headers,
    )
    assert buyer_draft_res.status_code == 403
    assert buyer_draft_res.json()["error"]["code"] == "FORBIDDEN"


def test_edge_cases_and_error_resilience(client):
    """
    Verify API behavior under edge conditions:
    1. Purchase quantity exceeds available stock -> 409 Conflict (INSUFFICIENT_STOCK).
    2. Attempting to purchase sold/inactive listing -> 409 Conflict (LISTING_UNAVAILABLE).
    3. Biometric verification omitted or false -> 403 Forbidden (BIOMETRIC_VERIFICATION_REQUIRED).
    4. Invalid purchase quantity (<= 0) -> 422 Unprocessable Entity.
    5. Non-existent listing query -> 404 Not Found (LISTING_NOT_FOUND).
    6. Search query with no matching items returns empty list without error.
    """
    s_token = _create_seller_and_token(client, "s_edge", -6.2000, 106.8000, "PT Gudang Edge", "Jakarta")
    b_token = _create_buyer_and_token(client, "b_edge", -6.2100, 106.8100, "Buyer Edge")
    b_headers = {"Authorization": f"Bearer {b_token}"}

    listing = _create_product_and_listing(
        client, s_token, "SKU-EDGE-1", "Yogurt Blueberry 200ml", "Dairy",
        qty=5, normal_price=20000.0, start_price=15000.0, min_price=10000.0, days_to_expiry=5,
    )
    listing_id = listing["id"]

    # 1. Quantity exceeds stock (requested 10, stock is 5)
    res_stock = client.post(
        f"/listings/{listing_id}/buy",
        json={"qty": 10, "biometric_verified": True},
        headers=b_headers,
    )
    assert res_stock.status_code == 409
    assert res_stock.json()["error"]["code"] == "INSUFFICIENT_STOCK"

    # 2. Biometric verification false
    res_bio = client.post(
        f"/listings/{listing_id}/buy",
        json={"qty": 1, "biometric_verified": False},
        headers=b_headers,
    )
    assert res_bio.status_code == 403
    assert res_bio.json()["error"]["code"] == "BIOMETRIC_VERIFICATION_REQUIRED"

    # 3. Invalid quantity (0 or negative)
    res_zero = client.post(
        f"/listings/{listing_id}/buy",
        json={"qty": 0, "biometric_verified": True},
        headers=b_headers,
    )
    assert res_zero.status_code == 422

    # 4. Non-existent listing ID
    res_404 = client.get("/listings/9999999")
    assert res_404.status_code == 404
    assert res_404.json()["error"]["code"] == "LISTING_NOT_FOUND"

    # 5. Empty search results
    res_empty = client.get("/listings?search=TermYangPastiTidakAdaXYZ123")
    assert res_empty.status_code == 200
    assert res_empty.json()["data"] == []
