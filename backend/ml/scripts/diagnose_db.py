"""Diagnosis: kenapa audit menemukan 0 baris ranking / sedikit listing terjual?
Pakai:  $env:DATABASE_URL="postgresql+psycopg://user:pw@host:5432/db"; python scripts/diagnose_db.py
Hanya SELECT (read-only)."""
import os
from sqlalchemy import create_engine, text

Q = {
    "jumlah baris per tabel": """
        SELECT 'users' t, COUNT(*) n FROM users UNION ALL SELECT 'sellers', COUNT(*) FROM sellers
        UNION ALL SELECT 'buyers', COUNT(*) FROM buyers UNION ALL SELECT 'products', COUNT(*) FROM products
        UNION ALL SELECT 'listings', COUNT(*) FROM listings UNION ALL SELECT 'offers', COUNT(*) FROM offers
        UNION ALL SELECT 'orders', COUNT(*) FROM orders""",
    "offers per status": "SELECT status, COUNT(*) n FROM offers GROUP BY status ORDER BY n DESC",
    "listings per status": "SELECT status, COUNT(*) n FROM listings GROUP BY status ORDER BY n DESC",
    "orders (total vs listing unik)": "SELECT COUNT(*) total_orders, COUNT(DISTINCT listing_id) listing_unik FROM orders",
    "kolom tambahan di offers (hasil migrasi)": """
        SELECT column_name FROM information_schema.columns
        WHERE table_name='offers' AND column_name IN
        ('category_match','buyer_orders_snapshot','buyer_reliability_snapshot','selection_source','model_version')""",
    "kandidat per listing di offers": """
        SELECT ROUND(AVG(c),1) rata2, MIN(c) min, MAX(c) max, COUNT(*) listing_punya_offer
        FROM (SELECT listing_id, COUNT(*) c FROM offers GROUP BY listing_id) x""",
    "listing terjual yang punya order": """
        SELECT COUNT(*) FROM listings l WHERE l.status='sold' AND EXISTS (SELECT 1 FROM orders o WHERE o.listing_id=l.id)""",
}

eng = create_engine(os.environ["DATABASE_URL"])
with eng.connect() as c:
    for name, sql in Q.items():
        print(f"\n== {name}")
        try:
            rows = c.execute(text(sql)).fetchall()
            for r in rows: print("  ", tuple(r))
            if not rows: print("   (kosong)")
        except Exception as e:
            c.rollback(); print("   ERROR:", str(e).splitlines()[0])
    cols = {r[0] for r in c.execute(text(Q["kolom tambahan di offers (hasil migrasi)"]))}
    if "category_match" in cols:
        n = c.execute(text("SELECT COUNT(*) total, COUNT(category_match) terisi FROM offers")).fetchone()
        print(f"\n== snapshot: offers total={n[0]}, category_match terisi={n[1]}")
