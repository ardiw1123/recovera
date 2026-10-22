from datetime import date, timedelta
import pytest


def _create_seller(client, email_prefix: str) -> dict:
    res = client.post("/auth/register", json={
        "email": f"{email_prefix}@recovera.id",
        "password": "Password123!",
        "role": "seller",
        "name": f"QA Seller {email_prefix}",
        "company_name": f"PT {email_prefix.title()} Pangan",
        "address": "Jl. Industri Pangan No. 8",
        "warehouse_lat": -6.2088,
        "warehouse_lng": 106.8456,
        "city": "Jakarta Pusat",
    })
    assert res.status_code == 201
    token = res.json()["data"]["access_token"]
    return {"Authorization": f"Bearer {token}"}


def test_seller_draft_creation_success_with_image(client):
    """
    ARDI-94 / Phase 2:
    Verify seller draft creation completes successfully without 500 error,
    accepts product image URLs from mobile gallery, and generates price recommendations.
    """
    headers = _create_seller(client, "qa_seller_img")

    exp_date = (date.today() + timedelta(days=45)).isoformat()
    draft_payload = {
        "sku": "SKU-QA-DAIRY-99",
        "barcode": "8991234567890",
        "name": "Yogurt Greek Probiotik 500g",
        "category": "Dairy",
        "brand": "Biokul",
        "storage_type": "chilled",
        "default_unit": "cup",
        "batch_number": "BATCH-2026-QA",
        "qty": 50,
        "normal_price": 50000.0,
        "min_price": 10000.0,
        "expiry_date": exp_date,
        "image_url": "https://storage.recovera.id/products/yogurt_greek.jpg",
    }

    res = client.post("/listings/seller/inventory/drafts", json=draft_payload, headers=headers)
    assert res.status_code == 201, f"Expected 201, got {res.status_code}: {res.text}"
    body = res.json()
    assert body["success"] is True
    data = body["data"]

    # Verify listing and product image persisted
    listing = data["listing"]
    assert listing["batch_number"] == "BATCH-2026-QA"
    assert listing["status"] == "draft"
    assert listing["product"]["name"] == "Yogurt Greek Probiotik 500g"
    assert listing["product"]["image_url"] == "https://storage.recovera.id/products/yogurt_greek.jpg"

    # Verify price recommendation is attached
    assert "price_recommendation" in data
    assert data["price_recommendation"]["suggested_price"] > 0
    assert "validation" in data


def test_seller_draft_invalid_expiry_handling(client):
    """Verify past expiry dates return 422 validation error instead of 500 crash."""
    headers = _create_seller(client, "qa_seller_past_exp")

    past_payload = {
        "sku": "SKU-PAST-01",
        "name": "Susu Pasteur 1L",
        "category": "Dairy",
        "storage_type": "chilled",
        "default_unit": "karton",
        "batch_number": "LOT-ERR-01",
        "qty": 20,
        "normal_price": 30000.0,
        "min_price": 5000.0,
        "expiry_date": (date.today() - timedelta(days=2)).isoformat(),
        "image_url": "https://storage.recovera.id/products/susu.jpg",
    }
    res = client.post("/listings/seller/inventory/drafts", json=past_payload, headers=headers)
    assert res.status_code == 422
    assert res.json()["error"]["code"] in ["INVALID_EXPIRY_DATE", "VALIDATION_ERROR"]


def test_seller_draft_invalid_quantity_handling(client):
    """Verify non-positive quantity returns 422 validation error instead of 500 crash."""
    headers = _create_seller(client, "qa_seller_zero_qty")

    qty_payload = {
        "sku": "SKU-ZERO-01",
        "name": "Susu Pasteur 1L",
        "category": "Dairy",
        "storage_type": "chilled",
        "default_unit": "karton",
        "batch_number": "LOT-ERR-02",
        "qty": 0,
        "normal_price": 30000.0,
        "min_price": 5000.0,
        "expiry_date": (date.today() + timedelta(days=10)).isoformat(),
        "image_url": "https://storage.recovera.id/products/susu.jpg",
    }
    res = client.post("/listings/seller/inventory/drafts", json=qty_payload, headers=headers)
    assert res.status_code == 422
    assert res.json()["error"]["code"] in ["INVALID_QUANTITY", "VALIDATION_ERROR"]


def test_seller_draft_invalid_pricing_handling(client):
    """Verify negative price or min_price > normal_price returns 422 instead of 500 crash."""
    headers = _create_seller(client, "qa_seller_bad_price")

    bad_price_payload = {
        "sku": "SKU-BADP-01",
        "name": "Susu Pasteur 1L",
        "category": "Dairy",
        "storage_type": "chilled",
        "default_unit": "karton",
        "batch_number": "LOT-ERR-03",
        "qty": 10,
        "normal_price": 20000.0,
        "min_price": 35000.0,  # min > normal
        "expiry_date": (date.today() + timedelta(days=10)).isoformat(),
        "image_url": "https://storage.recovera.id/products/susu.jpg",
    }
    res = client.post("/listings/seller/inventory/drafts", json=bad_price_payload, headers=headers)
    assert res.status_code == 422
    assert res.json()["error"]["code"] in ["INVALID_PRICE_RANGE", "INVALID_MIN_PRICE", "VALIDATION_ERROR"]


def test_seller_draft_update_and_validate_progression(client):
    """
    ARDI-94 / ARDI-96:
    Verify seller draft editing, image replacement, and validate endpoint progression.
    """
    headers = _create_seller(client, "qa_seller_prog")

    create_res = client.post("/listings/seller/inventory/drafts", json={
        "sku": "SKU-PROG-01",
        "name": "Roti Gandum Utuh",
        "category": "Bakery",
        "storage_type": "ambient",
        "default_unit": "pack",
        "batch_number": "LOT-ROTI-01",
        "qty": 30,
        "normal_price": 40000.0,
        "min_price": 5000.0,
        "expiry_date": (date.today() + timedelta(days=45)).isoformat(),
        "image_url": "https://storage.recovera.id/products/roti_gandum.jpg",
    }, headers=headers)
    assert create_res.status_code == 201, f"Create failed: {create_res.text}"
    listing_id = create_res.json()["data"]["listing"]["id"]

    # Patch image and quantity
    patch_res = client.patch(f"/listings/seller/inventory/{listing_id}", json={
        "qty": 35,
        "image_url": "https://storage.recovera.id/products/roti_gandum_edited.jpg",
    }, headers=headers)
    assert patch_res.status_code == 200
    assert patch_res.json()["data"]["listing"]["qty"] == 35
    assert patch_res.json()["data"]["listing"]["product"]["image_url"] == "https://storage.recovera.id/products/roti_gandum_edited.jpg"

    # Validate draft
    val_res = client.post(f"/listings/seller/inventory/{listing_id}/validate", headers=headers)
    assert val_res.status_code == 200
    assert val_res.json()["data"]["status"] == "review"
    assert val_res.json()["data"]["valid"] is True


def test_buyer_profile_custom_distance_configuration(client):
    """
    ARDI-94 / Phase 3:
    Verify buyer profile update allows configuring dynamic search radius (`max_radius_km`).
    """
    b_res = client.post("/auth/register", json={
        "email": "qa_buyer_radius@recovera.id",
        "password": "Password123!",
        "role": "buyer",
        "name": "QA Radius Buyer",
        "business_type": "hotel",
        "address": "Jl. MH Thamrin No. 1",
        "base_lat": -6.1950,
        "base_lng": 106.8230,
    })
    assert b_res.status_code == 201
    buyer_token = b_res.json()["data"]["access_token"]
    headers = {"Authorization": f"Bearer {buyer_token}"}

    # Default profile check
    prof_res = client.get("/profile", headers=headers)
    assert prof_res.status_code == 200
    buyer_data = prof_res.json()["data"]["buyer"]
    assert buyer_data["max_radius_km"] == 15.0

    # Update to custom radius (e.g. 50 km)
    patch_res = client.patch("/profile", json={"max_radius_km": 50.0}, headers=headers)
    assert patch_res.status_code == 200
    assert patch_res.json()["data"]["buyer"]["max_radius_km"] == 50.0

    # Negative / zero radius validation
    invalid_patch = client.patch("/profile", json={"max_radius_km": 0.0}, headers=headers)
    assert invalid_patch.status_code == 422
    assert invalid_patch.json()["error"]["code"] == "INVALID_RADIUS"


def test_listings_dynamic_distance_query_filtering(client):
    """
    ARDI-94 / Phase 3:
    Verify listing search service respects custom radius_km query parameters beyond 15 km.
    """
    headers = _create_seller(client, "qa_seller_dist_monas")

    # Create & publish listing
    draft_res = client.post("/listings/seller/inventory/drafts", json={
        "sku": "SKU-DIST-01",
        "name": "Keju Edam Import 1kg",
        "category": "Dairy",
        "storage_type": "chilled",
        "default_unit": "pack",
        "batch_number": "LOT-KEJU-01",
        "qty": 40,
        "normal_price": 120000.0,
        "min_price": 20000.0,
        "expiry_date": (date.today() + timedelta(days=45)).isoformat(),
        "image_url": "https://storage.recovera.id/products/keju_edam.jpg",
    }, headers=headers)
    assert draft_res.status_code == 201
    listing_id = draft_res.json()["data"]["listing"]["id"]
    pub_res = client.post(f"/listings/seller/inventory/{listing_id}/publish", headers=headers)
    assert pub_res.status_code == 200

    # 2. Buyer query from Bogor (~45 km away from Monas: -6.5971, 106.8060)
    bogor_lat = -6.5971
    bogor_lng = 106.8060

    # Query with default 15 km radius -> Should NOT find the listing
    res_15km = client.get("/listings", params={
        "lat": bogor_lat,
        "lng": bogor_lng,
        "radius_km": 15.0,
    })
    assert res_15km.status_code == 200
    items_15km = res_15km.json()["data"]
    matching_15 = [it for it in items_15km if it["id"] == listing_id]
    assert len(matching_15) == 0, "Listing should be excluded under 15 km radius"

    # Query with expanded 60 km radius -> MUST find the listing
    res_60km = client.get("/listings", params={
        "lat": bogor_lat,
        "lng": bogor_lng,
        "radius_km": 60.0,
    })
    assert res_60km.status_code == 200
    items_60km = res_60km.json()["data"]
    matching_60 = [it for it in items_60km if it["id"] == listing_id]
    assert len(matching_60) == 1, "Listing must be included under expanded 60 km radius"
    assert matching_60[0]["distance_km"] > 35.0
    assert matching_60[0]["distance_km"] < 60.0


def test_delete_draft_and_expiry_less_than_30_days(client):
    """Verify draft can be deleted and expiry < 30 days is rejected."""
    headers_exp = _create_seller(client, "qa_seller_exp_short")

    # 1. Reject if expiry < 30 days
    rej_res = client.post("/listings/seller/inventory/drafts", json={
        "sku": "SKU-EXP-SHORT",
        "name": "Susu Cepat Basi",
        "category": "Dairy",
        "storage_type": "chilled",
        "default_unit": "karton",
        "batch_number": "LOT-EXP-SHORT",
        "qty": 10,
        "normal_price": 25000.0,
        "min_price": 5000.0,
        "expiry_date": (date.today() + timedelta(days=15)).isoformat(),
        "image_url": "https://storage.recovera.id/products/susu_short.jpg",
    }, headers=headers_exp)
    assert rej_res.status_code == 422
    assert rej_res.json()["error"]["code"] == "INVALID_EXPIRY_DATE"

    # 2. Reject if image_url is missing
    headers_img = _create_seller(client, "qa_seller_no_img")
    no_img_res = client.post("/listings/seller/inventory/drafts", json={
        "sku": "SKU-NO-IMG",
        "name": "Produk Tanpa Foto",
        "category": "Dairy",
        "storage_type": "chilled",
        "default_unit": "karton",
        "batch_number": "LOT-NO-IMG",
        "qty": 10,
        "normal_price": 25000.0,
        "min_price": 5000.0,
        "expiry_date": (date.today() + timedelta(days=40)).isoformat(),
        "image_url": "",
    }, headers=headers_img)
    assert no_img_res.status_code == 422
    assert no_img_res.json()["error"]["code"] in ["IMAGE_REQUIRED", "VALIDATION_ERROR"]

    # 3. Create valid draft with expiry >= 30 days and valid image
    headers_ok = _create_seller(client, "qa_seller_ok_del")
    ok_res = client.post("/listings/seller/inventory/drafts", json={
        "sku": "SKU-DEL-OK",
        "name": "Beras Premium 5kg",
        "category": "Flour & Grain",
        "storage_type": "ambient",
        "default_unit": "karung",
        "batch_number": "LOT-DEL-OK",
        "qty": 20,
        "normal_price": 75000.0,
        "min_price": 25000.0,
        "expiry_date": (date.today() + timedelta(days=60)).isoformat(),
        "image_url": "https://storage.recovera.id/products/beras.jpg",
    }, headers=headers_ok)
    assert ok_res.status_code == 201
    draft_id = ok_res.json()["data"]["listing"]["id"]

    # 4. Delete the draft
    del_res = client.delete(f"/listings/seller/inventory/{draft_id}", headers=headers_ok)
    assert del_res.status_code == 200
    assert del_res.json()["data"]["deleted"] is True

    # 5. Verify it is gone from inventory
    inv_res = client.get("/listings/seller/inventory", headers=headers_ok)
    assert inv_res.status_code == 200
    assert not any(item["id"] == draft_id for item in inv_res.json()["data"])

