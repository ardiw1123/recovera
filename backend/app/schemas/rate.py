from pydantic import BaseModel


class RatesResponse(BaseModel):
    base_currency: str = "IDR"
    rates: dict[str, float]
    updated_at: str
