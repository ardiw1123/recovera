from datetime import datetime, timezone
from sqlalchemy.orm import Session
from fastapi import status

from app.core.exceptions import AppException
from app.core.security import (
    create_access_token,
    create_refresh_token,
    hash_password,
    hash_token,
    verify_password,
)
from app.models.user import Buyer, RefreshToken, Seller, User
from app.schemas.auth import LoginRequest, RegisterRequest, TokenResponse


def register_user(db: Session, req: RegisterRequest) -> TokenResponse:
    existing = db.query(User).filter(User.email == req.email).first()
    if existing:
        raise AppException(
            code="EMAIL_ALREADY_EXISTS",
            message="An account with this email address already exists",
            status_code=status.HTTP_409_CONFLICT,
        )

    user = User(
        email=req.email,
        password_hash=hash_password(req.password),
        role=req.role,
        name=req.name,
        phone=req.phone,
    )
    db.add(user)
    db.flush()

    if req.role == "seller":
        if not req.company_name:
            raise AppException(
                code="MISSING_SELLER_INFO",
                message="Company name is required for seller registration",
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            )
        seller = Seller(
            user_id=user.id,
            company_name=req.company_name,
            address=req.address or "Warehouse Address",
            warehouse_lat=req.warehouse_lat if req.warehouse_lat is not None else -6.2088,
            warehouse_lng=req.warehouse_lng if req.warehouse_lng is not None else 106.8456,
            city=req.city or "Jakarta",
        )
        db.add(seller)
    elif req.role == "buyer":
        buyer = Buyer(
            user_id=user.id,
            business_type=req.business_type or "resto",
            address=req.address or "Business Address",
            base_lat=req.base_lat if req.base_lat is not None else -6.2088,
            base_lng=req.base_lng if req.base_lng is not None else 106.8456,
            pref_categories=req.pref_categories,
        )
        db.add(buyer)

    raw_refresh_token, token_hash, expires_at = create_refresh_token()
    db_refresh = RefreshToken(
        user_id=user.id,
        token_hash=token_hash,
        expires_at=expires_at,
        is_revoked=False,
    )
    db.add(db_refresh)
    db.commit()
    db.refresh(user)

    access_token = create_access_token(subject=user.id, role=user.role, extra_claims={"name": user.name})
    return TokenResponse(
        access_token=access_token,
        refresh_token=raw_refresh_token,
        token_type="bearer",
        expires_in=3600,
        user_id=user.id,
        role=user.role,
        name=user.name,
    )


def login_user(db: Session, req: LoginRequest) -> TokenResponse:
    user = db.query(User).filter(User.email == req.email).first()
    if not user or not verify_password(req.password, user.password_hash):
        raise AppException(
            code="INVALID_CREDENTIALS",
            message="Invalid email or password",
            status_code=status.HTTP_401_UNAUTHORIZED,
        )

    raw_refresh_token, token_hash, expires_at = create_refresh_token()
    db_refresh = RefreshToken(
        user_id=user.id,
        token_hash=token_hash,
        expires_at=expires_at,
        is_revoked=False,
    )
    db.add(db_refresh)
    db.commit()

    access_token = create_access_token(subject=user.id, role=user.role, extra_claims={"name": user.name})
    return TokenResponse(
        access_token=access_token,
        refresh_token=raw_refresh_token,
        token_type="bearer",
        expires_in=3600,
        user_id=user.id,
        role=user.role,
        name=user.name,
    )


def refresh_access_token(db: Session, raw_refresh_token: str) -> TokenResponse:
    token_hash = hash_token(raw_refresh_token)
    db_token = db.query(RefreshToken).filter(
        RefreshToken.token_hash == token_hash,
        RefreshToken.is_revoked == False,
    ).first()

    if not db_token:
        raise AppException(
            code="INVALID_REFRESH_TOKEN",
            message="Refresh token is invalid or revoked",
            status_code=status.HTTP_401_UNAUTHORIZED,
        )

    # Compare aware vs naive datetime safely
    now_utc = datetime.now(timezone.utc)
    token_exp = db_token.expires_at
    if token_exp.tzinfo is None:
        token_exp = token_exp.replace(tzinfo=timezone.utc)

    if token_exp < now_utc:
        db_token.is_revoked = True
        db.commit()
        raise AppException(
            code="EXPIRED_REFRESH_TOKEN",
            message="Refresh token has expired",
            status_code=status.HTTP_401_UNAUTHORIZED,
        )

    user = db.query(User).filter(User.id == db_token.user_id).first()
    if not user:
        raise AppException(
            code="USER_NOT_FOUND",
            message="User not found",
            status_code=status.HTTP_401_UNAUTHORIZED,
        )

    # Issue new access token; rotate refresh token
    db_token.is_revoked = True
    new_raw_refresh, new_token_hash, new_expires_at = create_refresh_token()
    new_db_token = RefreshToken(
        user_id=user.id,
        token_hash=new_token_hash,
        expires_at=new_expires_at,
        is_revoked=False,
    )
    db.add(new_db_token)
    db.commit()

    access_token = create_access_token(subject=user.id, role=user.role, extra_claims={"name": user.name})
    return TokenResponse(
        access_token=access_token,
        refresh_token=new_raw_refresh,
        token_type="bearer",
        expires_in=3600,
        user_id=user.id,
        role=user.role,
        name=user.name,
    )


def logout_user(db: Session, user_id: int, raw_refresh_token: str | None = None) -> None:
    if raw_refresh_token:
        token_hash = hash_token(raw_refresh_token)
        tokens = db.query(RefreshToken).filter(
            RefreshToken.user_id == user_id,
            RefreshToken.token_hash == token_hash,
        ).all()
        for t in tokens:
            t.is_revoked = True
    else:
        # Revoke all active tokens for this user
        tokens = db.query(RefreshToken).filter(
            RefreshToken.user_id == user_id,
            RefreshToken.is_revoked == False,
        ).all()
        for t in tokens:
            t.is_revoked = True
    db.commit()
