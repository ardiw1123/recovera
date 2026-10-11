from fastapi import FastAPI, HTTPException, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

from app.schemas.envelope import wrap_error


class AppException(Exception):
    def __init__(self, code: str, message: str, status_code: int = status.HTTP_400_BAD_REQUEST):
        self.code = code
        self.message = message
        self.status_code = status_code
        super().__init__(message)


def register_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(AppException)
    async def app_exception_handler(_: Request, exc: AppException) -> JSONResponse:
        return JSONResponse(
            status_code=exc.status_code,
            content=wrap_error(exc.code, exc.message),
        )

    @app.exception_handler(HTTPException)
    async def http_exception_handler(_: Request, exc: HTTPException) -> JSONResponse:
        code = "HTTP_ERROR"
        if exc.status_code == status.HTTP_401_UNAUTHORIZED:
            code = "UNAUTHORIZED"
        elif exc.status_code == status.HTTP_403_FORBIDDEN:
            code = "FORBIDDEN"
        elif exc.status_code == status.HTTP_404_NOT_FOUND:
            code = "NOT_FOUND"
        elif exc.status_code == status.HTTP_409_CONFLICT:
            code = "CONFLICT"

        message = str(exc.detail) if isinstance(exc.detail, str) else "An error occurred"
        return JSONResponse(
            status_code=exc.status_code,
            content=wrap_error(code, message),
        )

    @app.exception_handler(RequestValidationError)
    async def validation_exception_handler(_: Request, exc: RequestValidationError) -> JSONResponse:
        messages: list[str] = []
        for error in exc.errors():
            loc = " -> ".join(str(loc_item) for loc_item in error.get("loc", []))
            msg = error.get("msg", "Invalid value")
            messages.append(f"{loc}: {msg}")
        joined_message = "; ".join(messages) if messages else "Invalid request data"
        return JSONResponse(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            content=wrap_error("VALIDATION_ERROR", joined_message),
        )

    @app.exception_handler(Exception)
    async def general_exception_handler(_: Request, exc: Exception) -> JSONResponse:
        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content=wrap_error("INTERNAL_SERVER_ERROR", "Internal server error occurred"),
        )
