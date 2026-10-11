from typing import Any, Generic, TypeVar
from pydantic import BaseModel

DataT = TypeVar("DataT")


class ErrorDetail(BaseModel):
    code: str
    message: str


class ErrorEnvelope(BaseModel):
    success: bool = False
    error: ErrorDetail


class ResponseEnvelope(BaseModel, Generic[DataT]):
    success: bool = True
    data: DataT


def wrap_success(data: Any) -> dict[str, Any]:
    return {"success": True, "data": data}


def wrap_error(code: str, message: str) -> dict[str, Any]:
    return {
        "success": False,
        "error": {
            "code": code,
            "message": message,
        },
    }
