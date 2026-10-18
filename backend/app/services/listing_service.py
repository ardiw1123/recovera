import math
from datetime import date, datetime, timedelta, timezone
from zoneinfo import ZoneInfo
from sqlalchemy.orm import Session
from sqlalchemy import or_

from app.models.listing import Listing
from app.models.product import Product
from app.models.user import Seller
from app.schemas.listing import MultiTimezoneSchedule


def calculate_haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    # Earth radius in kilometers
    r = 6371.0
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)

    a = math.sin(delta_phi / 2.0) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2.0) ** 2
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
    return round(r * c, 2)


def get_initial_discount_percentage(days_to_expiry: int) -> float:
    if days_to_expiry > 90:
        return 25.0
    elif days_to_expiry >= 60:
        return 30.0
    elif days_to_expiry >= 30:
        return 40.0
    elif days_to_expiry >= 15:
        return 50.0
    else:
        return 55.0


def calculate_current_dutch_price(listing: Listing) -> tuple[float, str | None]:
    now_utc = datetime.now(timezone.utc)
    start_at = listing.auction_start_at
    if start_at.tzinfo is None:
        start_at = start_at.replace(tzinfo=timezone.utc)

    end_at = listing.auction_end_at
    if end_at.tzinfo is None:
        end_at = end_at.replace(tzinfo=timezone.utc)

    start_price = float(listing.start_price)
    min_price = float(listing.min_price)
    interval_minutes = max(listing.drop_interval_minutes, 1)
    drop_pct = float(listing.drop_percentage)

    if now_utc <= start_at:
        return start_price, (start_at + timedelta(minutes=interval_minutes)).isoformat()

    if now_utc >= end_at or listing.status != "active":
        return min_price, None

    elapsed_minutes = (now_utc - start_at).total_seconds() / 60.0
    intervals_passed = int(elapsed_minutes // interval_minutes)

    total_drop_factor = (intervals_passed * drop_pct) / 100.0
    calculated_price = start_price * (1.0 - total_drop_factor)

    # Invariant: current price never drops below reserve min_price
    final_price = max(min_price, round(calculated_price, 2))

    next_drop_dt = start_at + timedelta(minutes=(intervals_passed + 1) * interval_minutes)
    next_drop_str = next_drop_dt.isoformat() if next_drop_dt < end_at else None

    return final_price, next_drop_str


def format_multi_timezone(dt: datetime) -> MultiTimezoneSchedule:
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)

    # Timezone conversions for WIB, WITA, WIT, and London
    tz_wib = ZoneInfo("Asia/Jakarta")
    tz_wita = ZoneInfo("Asia/Makassar")
    tz_wit = ZoneInfo("Asia/Jayapura")
    tz_london = ZoneInfo("Europe/London")

    return MultiTimezoneSchedule(
        wib=dt.astimezone(tz_wib).strftime("%Y-%m-%d %H:%M:%S WIB"),
        wita=dt.astimezone(tz_wita).strftime("%Y-%m-%d %H:%M:%S WITA"),
        wit=dt.astimezone(tz_wit).strftime("%Y-%m-%d %H:%M:%S WIT"),
        london=dt.astimezone(tz_london).strftime("%Y-%m-%d %H:%M:%S %Z"),
    )


def search_listings(
    db: Session,
    search: str | None = None,
    category: str | None = None,
    lat: float | None = None,
    lng: float | None = None,
    radius_km: float | None = None,
    max_price: float | None = None,
    min_days: int | None = None,
    sort: str | None = None,
    page: int = 1,
    page_size: int = 20,
) -> tuple[list[dict], int]:
    query = db.query(Listing).join(Product).join(Seller).filter(Listing.status == "active")

    if search:
        search_filter = f"%{search.strip()}%"
        query = query.filter(or_(Product.name.ilike(search_filter), Product.brand.ilike(search_filter)))

    if category:
        query = query.filter(Product.category.ilike(category.strip()))

    today = date.today()
    if min_days is not None:
        min_expiry_date = today + timedelta(days=min_days)
        query = query.filter(Listing.expiry_date >= min_expiry_date)

    listings = query.all()

    # Dynamic pricing evaluation and geographical filtering
    results: list[dict] = []
    for item in listings:
        cur_price, next_drop = calculate_current_dutch_price(item)

        if max_price is not None and cur_price > max_price:
            continue

        distance: float | None = None
        if lat is not None and lng is not None:
            distance = calculate_haversine_distance(
                lat, lng, item.seller.warehouse_lat, item.seller.warehouse_lng
            )
            if radius_km is not None and distance > radius_km:
                continue

        # Compute recommendation match scoring and pricing metrics
        days_left = (item.expiry_date - date.today()).days
        # Match score is based on proximity (closer = higher score) and days to expiry
        if lat is not None and lng is not None and distance is not None:
            # Base score decreases with distance; penalize far listings
            proximity_score = max(0, 1.0 - (distance / 50.0))
            # Discount factor based on remaining shelf life
            discount_factor = min(1.0, days_left / 30.0) if days_left > 0 else 0.0
            match_score = round(proximity_score * discount_factor, 3)
        else:
            match_score = None

        # Calculate discount percentage from normal price to start price
        if item.normal_price and item.normal_price > 0:
            discount_pct = round(((float(item.normal_price) - cur_price) / float(item.normal_price)) * 100, 2)
        else:
            discount_pct = None

        results.append({
            "listing": item,
            "current_price": cur_price,
            "next_drop_at": next_drop,
            "distance_km": distance,
            "match_score": match_score,
            "discount_pct": discount_pct,
            "days_to_expiry": days_left,
        })

    # Sort evaluation: nearest / cheapest / expiring_soon
    if sort == "nearest" and lat is not None and lng is not None:
        results.sort(key=lambda x: x["distance_km"] if x["distance_km"] is not None else 999999)
    elif sort == "cheapest":
        results.sort(key=lambda x: x["current_price"])
    elif sort == "expiring_soon":
        results.sort(key=lambda x: x["listing"].expiry_date)

    total_count = len(results)
    start_idx = (page - 1) * page_size
    end_idx = start_idx + page_size
    paginated_results = results[start_idx:end_idx]

    return paginated_results, total_count
