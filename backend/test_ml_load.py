import sys
from pathlib import Path

# Add backend directory to path
sys.path.insert(0, str(Path(__file__).parent))

from app.ai.engine import AIEngine

def main():
    print("Testing AIEngine initialization...")
    engine = AIEngine(use_ml=True)
    
    print(f"Pricing model loaded: {engine.pricing is not None}")
    print(f"Ranking model loaded: {engine.ranking is not None}")
    
    sample_listing = {
        "category": "Dairy",
        "storage_type": "chilled",
        "days_to_expiry": 20,
        "qty": 50,
        "normal_price": 50000.0,
        "min_price": 25000.0,
    }
    
    advice = engine.advise_price(sample_listing)
    print("\n[1] Result advise_price:")
    print(f"  Source: {advice.source}")
    print(f"  Discount: {advice.discount_pct}%")
    print(f"  Suggested Price: Rp {advice.suggested_price:,.0f}")
    print(f"  Divert: {advice.divert}")

    # Test Ranking Model
    import pandas as pd
    sample_buyers = pd.DataFrame([
        {
            "buyer_id": 101,
            "base_lat": -7.7950,
            "base_lng": 110.3690,
            "max_radius_km": 15,
            "has_cold_storage": True,
            "pref_categories": ["Dairy", "Beverage"],
            "business_type": "resto",
            "total_orders_completed": 35,
            "payment_reliability_score": 0.95,
        },
        {
            "buyer_id": 102,
            "base_lat": -7.7920,
            "base_lng": 110.3650,
            "max_radius_km": 10,
            "has_cold_storage": True,
            "pref_categories": ["Dairy"],
            "business_type": "bakery",
            "total_orders_completed": 12,
            "payment_reliability_score": 0.90,
        },
        {
            "buyer_id": 103,
            "base_lat": -7.8500,
            "base_lng": 110.4500,
            "max_radius_km": 5, # too far (> 5km) -> will be filtered out by guardrail
            "has_cold_storage": False,
            "pref_categories": ["Oil"],
            "business_type": "warung",
            "total_orders_completed": 2,
            "payment_reliability_score": 0.70,
        },
    ])
    
    ranking_listing = {
        "warehouse_lat": -7.7956,
        "warehouse_lng": 110.3695,
        "days_to_expiry": 20,
        "offered_discount_pct": advice.discount_pct or 30.0,
        "storage_type": "chilled",
        "category": "Dairy",
    }
    
    matches = engine.match_buyers(ranking_listing, sample_buyers, k=5)
    print(f"\n[2] Result match_buyers (Found {len(matches)} matched buyers):")
    for idx, m in enumerate(matches, 1):
        print(f"  Rank #{idx}: Buyer ID {m['buyer_id']} | Score: {m['match_score']:.3f} | Distance: {m['distance_km']} km | Source: {m['source']}")

if __name__ == "__main__":
    main()
