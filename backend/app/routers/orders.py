from typing import Annotated
from fastapi import APIRouter, Body, Path, status

from app.core.dependencies import CurrentUserDep, DbSessionDep
from app.core.exceptions import AppException
from app.models.listing import Listing
from app.models.order import Order
from app.models.user import Buyer, Seller
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
            warehouse_address=listing.seller.address if listing.seller else None,
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

    # Status state machine check
    order.status = payload.status
    db.commit()
    db.refresh(order)

    return wrap_success(_format_order(order))
