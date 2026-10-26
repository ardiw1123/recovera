from typing import Annotated
from fastapi import APIRouter, Body, File, Request, UploadFile, status
from fastapi.concurrency import run_in_threadpool

from app.core.dependencies import CurrentUserDep, DbSessionDep, RequireSellerDep
from app.core.exceptions import AppException
from app.schemas.ai import (
    ChatRequest,
    ChatResponse,
    InvoiceOcrResponse,
    PriceAdviceRequest,
    PriceAdviceResponse,
)
from app.schemas.envelope import ResponseEnvelope, wrap_success
from app.services.ai_service import (
    calculate_price_advice,
    process_chat_message,
    process_invoice_ocr,
)

router = APIRouter(prefix="/ai", tags=["ai"])


@router.post(
    "/chat",
    status_code=status.HTTP_200_OK,
    response_model=ResponseEnvelope[ChatResponse],
)
async def chat_with_assistant(
    request: Request,
    user: CurrentUserDep,
    db: DbSessionDep,
    payload: Annotated[ChatRequest, Body()],
) -> dict:
    engine = getattr(request.app.state, "ai", None)
    response = await process_chat_message(
        db=db,
        user=user,
        payload=payload,
        ai_engine=engine,
    )
    return wrap_success(response.model_dump())


@router.post(
    "/invoice",
    status_code=status.HTTP_200_OK,
    response_model=ResponseEnvelope[InvoiceOcrResponse],
)
async def extract_invoice(
    _: RequireSellerDep,
    file: Annotated[UploadFile, File(description="Invoice image file (PNG/JPEG/PDF)")],
) -> dict:
    if not file.filename:
        raise AppException(
            code="INVALID_FILE",
            message="No file uploaded or filename is empty",
            status_code=status.HTTP_400_BAD_REQUEST,
        )

    content = await file.read()
    if len(content) == 0:
        raise AppException(
            code="EMPTY_FILE",
            message="Uploaded invoice file is empty",
            status_code=status.HTTP_400_BAD_REQUEST,
        )

    result = await process_invoice_ocr(filename=file.filename, content=content)
    return wrap_success(result.model_dump())


@router.post(
    "/price-advice",
    status_code=status.HTTP_200_OK,
    response_model=ResponseEnvelope[PriceAdviceResponse],
)
async def get_price_advice(
    request: Request,
    _: RequireSellerDep,
    payload: Annotated[PriceAdviceRequest, Body()],
) -> dict:
    engine = getattr(request.app.state, "ai", None)
    advice = await run_in_threadpool(
        calculate_price_advice,
        normal_price=payload.normal_price,
        expiry_date_str=payload.expiry_date,
        category=payload.category,
        qty=payload.qty,
        storage_type=payload.storage_type,
        min_price=payload.min_price,
        ai_engine=engine,
    )
    return wrap_success(advice.model_dump())


