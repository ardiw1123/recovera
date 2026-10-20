from typing import Annotated
from fastapi import Depends, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.config import get_settings
from app.core.exceptions import AppException
from app.core.security import decode_token
from app.database import get_db
from app.models.user import User

settings = get_settings()
security_bearer = HTTPBearer(auto_error=False)

DbSessionDep = Annotated[Session, Depends(get_db)]


def get_current_user(
    db: DbSessionDep,
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(security_bearer)],
) -> User:
    if not credentials or not credentials.credentials:
        if settings.debug:
            mock_seller = db.query(User).filter(User.role == "seller").first()
            if mock_seller:
                return mock_seller
            return User(id=1, email="seller@recovera.dev", role="seller", is_verified=True)
        raise AppException(
            code="UNAUTHORIZED",
            message="Missing or invalid authentication credentials",
            status_code=status.HTTP_401_UNAUTHORIZED,
        )

    try:
        payload = decode_token(credentials.credentials)
        user_id_str = payload.get("sub")
        if not user_id_str:
            raise AppException(
                code="UNAUTHORIZED",
                message="Invalid token claims",
                status_code=status.HTTP_401_UNAUTHORIZED,
            )
        user_id = int(user_id_str)
    except Exception:
        raise AppException(
            code="UNAUTHORIZED",
            message="Token has expired or is invalid",
            status_code=status.HTTP_401_UNAUTHORIZED,
        )

    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise AppException(
            code="USER_NOT_FOUND",
            message="User associated with token not found",
            status_code=status.HTTP_401_UNAUTHORIZED,
        )

    return user


CurrentUserDep = Annotated[User, Depends(get_current_user)]


def require_role(required_role: str):
    def role_checker(current_user: CurrentUserDep) -> User:
        if current_user.role != required_role:
            raise AppException(
                code="FORBIDDEN",
                message=f"Access denied: this endpoint requires {required_role} role",
                status_code=status.HTTP_403_FORBIDDEN,
            )
        return current_user

    return role_checker


RequireSellerDep = Annotated[User, Depends(require_role("seller"))]
RequireBuyerDep = Annotated[User, Depends(require_role("buyer"))]
