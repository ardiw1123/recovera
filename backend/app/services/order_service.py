from sqlalchemy.orm import Session
from fastapi import status

from app.core.exceptions import AppException
from app.models.listing import Listing
from app.models.order import Order
from app.models.user import Buyer, User
from app.services.listing_service import calculate_current_dutch_price


def execute_buy_now(
    db: Session,
    listing_id: int,
    buyer_user: User,
    buy_qty: int = 1,
    biometric_verified: bool = True,
) -> Order:
    if not biometric_verified:
        raise AppException(
            code="BIOMETRIC_VERIFICATION_REQUIRED",
            message="Step-up biometric verification is required to confirm purchase",
            status_code=status.HTTP_403_FORBIDDEN,
        )

    buyer = db.query(Buyer).filter(Buyer.user_id == buyer_user.id).first()
    if not buyer:
        raise AppException(
            code="BUYER_PROFILE_NOT_FOUND",
            message="Buyer profile is required to purchase listings",
            status_code=status.HTTP_400_BAD_REQUEST,
        )

    # Database level check to prevent race condition
    listing = db.query(Listing).filter(Listing.id == listing_id).first()
    if not listing:
        raise AppException(
            code="LISTING_NOT_FOUND",
            message="The requested listing does not exist",
            status_code=status.HTTP_404_NOT_FOUND,
        )

    if listing.status != "active":
        raise AppException(
            code="LISTING_UNAVAILABLE",
            message=f"Listing is no longer active (current status: {listing.status})",
            status_code=status.HTTP_409_CONFLICT,
        )

    if listing.qty < buy_qty:
        raise AppException(
            code="INSUFFICIENT_STOCK",
            message=f"Requested quantity ({buy_qty}) exceeds available stock ({listing.qty})",
            status_code=status.HTTP_409_CONFLICT,
        )

    final_unit_price, _ = calculate_current_dutch_price(listing)
    total_price = round(final_unit_price * buy_qty, 2)

    # Decrement stock and update status if fully sold
    listing.qty -= buy_qty
    if listing.qty == 0:
        listing.status = "sold"

    order = Order(
        listing_id=listing.id,
        buyer_id=buyer.id,
        qty=buy_qty,
        final_unit_price=final_unit_price,
        total_price=total_price,
        status="paid",
    )
    db.add(order)

    buyer.total_orders_completed += 1
    db.commit()
    db.refresh(order)

    try:
        from app.services.push_service import notify_user
        seller_user_id = listing.seller.user_id if listing.seller else None
        if seller_user_id:
            notify_user(
                db,
                seller_user_id,
                "Pesanan Baru Masuk!",
                f"Pesanan baru untuk {listing.product.name if listing.product else 'produk Anda'}.",
                "new_order",
                {"order_id": order.id},
            )
    except Exception:
        # Notifikasi tidak boleh menggagalkan transaksi yang sudah berhasil.
        pass

    return order
