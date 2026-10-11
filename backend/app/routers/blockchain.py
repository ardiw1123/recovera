from typing import Annotated
from fastapi import APIRouter, Path, status

from app.schemas.donation import BlockchainVerifyResponse
from app.schemas.envelope import ResponseEnvelope, wrap_success
from app.services.donation_service import verify_blockchain_hash

router = APIRouter(prefix="/blockchain", tags=["blockchain"])


@router.get(
    "/verify/{tx_hash}",
    status_code=status.HTTP_200_OK,
    response_model=ResponseEnvelope[BlockchainVerifyResponse],
)
async def verify_tx_hash(
    tx_hash: Annotated[str, Path(description="Transaction hash to verify on BOT Chain Testnet")],
) -> dict:
    result = verify_blockchain_hash(tx_hash)
    return wrap_success(result.model_dump())
