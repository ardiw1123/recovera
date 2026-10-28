from datetime import datetime, timedelta, timezone
from typing import Annotated
from fastapi import APIRouter, Body, Path, status

from app.core.dependencies import CurrentUserDep, DbSessionDep
from app.core.exceptions import AppException
from app.models.listing import Listing
from app.models.order import Order
from app.models.user import Buyer, Seller
from app.services.push_service import notify_user
from app.schemas.envelope import ResponseEnvelope, wrap_success
from app.schemas.order import OrderProductDetail, OrderResponse, OrderStatusUpdate

router = APIRouter(prefix="/orders", tags=["orders"])


def _format_order(order: Order) -> dict:
    listing = order.listing
    product_detail = None
    if listing:
        product_detail = OrderProductDetail(
            product_name=listing.product.name if listing.product else "Food Item",
            category=listing.product.category if listing.product else "General",
            batch_number=listing.batch_number,
            warehouse_lat=listing.seller.warehouse_lat if listing.seller else None,
            warehouse_lng=listing.seller.warehouse_lng if listing.seller else None,
            warehouse_address=(
                f"{listing.seller.company_name}, {listing.seller.city or listing.seller.address}"
                if (listing.seller and listing.seller.company_name)
                else (listing.seller.address if listing.seller else None)
            ),
        ).model_dump()

    return OrderResponse(
        id=order.id,
        listing_id=order.listing_id,
        buyer_id=order.buyer_id,
        qty=order.qty,
        final_unit_price=float(order.final_unit_price),
        total_price=float(order.total_price),
        status=order.status,
        created_at=order.created_at.isoformat(),
        product_detail=product_detail,
    ).model_dump()


@router.get(
    "",
    status_code=status.HTTP_200_OK,
    response_model=ResponseEnvelope[list[OrderResponse]],
)
async def list_orders(
    db: DbSessionDep,
    current_user: CurrentUserDep,
) -> dict:
    if current_user.role == "buyer":
        buyer = db.query(Buyer).filter(Buyer.user_id == current_user.id).first()
        if not buyer:
            return wrap_success([])
        orders = db.query(Order).filter(Order.buyer_id == buyer.id).order_by(Order.created_at.desc()).all()
    elif current_user.role == "seller":
        seller = db.query(Seller).filter(Seller.user_id == current_user.id).first()
        if not seller:
            return wrap_success([])
        orders = (
            db.query(Order)
            .join(Listing)
            .filter(Listing.seller_id == seller.id)
            .order_by(Order.created_at.desc())
            .all()
        )
    else:
        orders = db.query(Order).order_by(Order.created_at.desc()).all()

    formatted = [_format_order(o) for o in orders]
    return wrap_success(formatted)


@router.get(
    "/{order_id}",
    status_code=status.HTTP_200_OK,
    response_model=ResponseEnvelope[OrderResponse],
)
async def get_order_detail(
    db: DbSessionDep,
    current_user: CurrentUserDep,
    order_id: Annotated[int, Path(ge=1, description="Order ID")],
) -> dict:
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise AppException(
            code="ORDER_NOT_FOUND",
            message=f"Order with ID {order_id} not found",
            status_code=status.HTTP_404_NOT_FOUND,
        )

    # Authorization check
    if current_user.role == "buyer":
        buyer = db.query(Buyer).filter(Buyer.user_id == current_user.id).first()
        if not buyer or order.buyer_id != buyer.id:
            raise AppException(
                code="FORBIDDEN",
                message="You do not have permission to view this order",
                status_code=status.HTTP_403_FORBIDDEN,
            )
    elif current_user.role == "seller":
        seller = db.query(Seller).filter(Seller.user_id == current_user.id).first()
        if not seller or (order.listing and order.listing.seller_id != seller.id):
            raise AppException(
                code="FORBIDDEN",
                message="You do not have permission to view this order",
                status_code=status.HTTP_403_FORBIDDEN,
            )

    return wrap_success(_format_order(order))


@router.patch(
    "/{order_id}/status",
    status_code=status.HTTP_200_OK,
    response_model=ResponseEnvelope[OrderResponse],
)
async def update_order_status(
    db: DbSessionDep,
    current_user: CurrentUserDep,
    order_id: Annotated[int, Path(ge=1, description="Order ID")],
    payload: Annotated[OrderStatusUpdate, Body()],
) -> dict:
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise AppException(
            code="ORDER_NOT_FOUND",
            message=f"Order with ID {order_id} not found",
            status_code=status.HTTP_404_NOT_FOUND,
        )

    seller = db.query(Seller).filter(Seller.user_id == current_user.id).first()
    if not seller or not order.listing or order.listing.seller_id != seller.id:
        raise AppException("FORBIDDEN", "You do not have permission to update this order", status.HTTP_403_FORBIDDEN)
    if (order.status, payload.status) not in {("paid", "in_progress"), ("in_progress", "completed")}:
        raise AppException("INVALID_ORDER_TRANSITION", f"Cannot change order from {order.status} to {payload.status}", status.HTTP_409_CONFLICT)

    order.status = payload.status
    should_notify = payload.status == "in_progress" and (
        order.last_notification_sent_at is None
        or datetime.now(timezone.utc) - order.last_notification_sent_at.replace(tzinfo=timezone.utc) >= timedelta(hours=3)
    )
    if should_notify:
        order.last_notification_sent_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(order)

    if should_notify:
        try:
            buyer_user_id = order.buyer.user_id if order.buyer else None
            if buyer_user_id:
                notify_user(db, buyer_user_id, "Pesanan Anda Sudah Siap Diambil!", "Produk yang Anda pesan sudah disiapkan penjual.", "order_ready", {"order_id": order.id})
        except Exception:
            pass

    return wrap_success(_format_order(order))


@router.post("/{order_id}/remind-seller", status_code=status.HTTP_200_OK)
async def remind_seller(
    db: DbSessionDep,
    current_user: CurrentUserDep,
    order_id: Annotated[int, Path(ge=1, description="Order ID")],
) -> dict:
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise AppException("ORDER_NOT_FOUND", f"Order with ID {order_id} not found", status.HTTP_404_NOT_FOUND)
    buyer = db.query(Buyer).filter(Buyer.user_id == current_user.id).first()
    if not buyer or order.buyer_id != buyer.id:
        raise AppException("FORBIDDEN", "You do not have permission to remind this order's seller", status.HTTP_403_FORBIDDEN)
    if order.status != "paid":
        raise AppException("ORDER_NOT_WAITING", "Pengingat hanya tersedia untuk pesanan yang menunggu disiapkan", status.HTTP_409_CONFLICT)
    now = datetime.now(timezone.utc)
    sent_at = order.last_notification_sent_at
    if sent_at and now - sent_at.replace(tzinfo=timezone.utc) < timedelta(hours=3):
        raise AppException("REMINDER_RATE_LIMITED", "Pengingat sudah dikirim. Silakan tunggu 3 jam.", status.HTTP_429_TOO_MANY_REQUESTS)
    seller_user_id = order.listing.seller.user_id if order.listing and order.listing.seller else None
    if not seller_user_id:
        raise AppException("SELLER_NOT_FOUND", "Penjual pesanan ini tidak ditemukan", status.HTTP_404_NOT_FOUND)
    order.last_notification_sent_at = now
    db.commit()
    notify_user(db, seller_user_id, "Pembeli menunggu pesanan Anda", "Pembeli mengingatkan Anda untuk menyiapkan pesanannya.", "reminder", {"order_id": order.id})
    return wrap_success({"sent": True, "retry_after_seconds": 10800})
