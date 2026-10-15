from datetime import datetime, timezone
from fastapi import APIRouter, status

from app.schemas.envelope import ResponseEnvelope, wrap_success
from app.schemas.rate import RatesResponse
from app.services.donation_service import get_current_exchange_rates

router = APIRouter(prefix="/rates", tags=["rates"])


@router.get(
    "",
    status_code=status.HTTP_200_OK,
    response_model=ResponseEnvelope[RatesResponse],
)
async def get_rates() -> dict:
    rates = get_current_exchange_rates()
    now_str = datetime.now(timezone.utc).isoformat()
    return wrap_success({
        "base_currency": "IDR",
        "rates": rates,
        "updated_at": now_str,
    })
