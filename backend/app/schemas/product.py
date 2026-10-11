from pydantic import BaseModel


class ProductResponse(BaseModel):
    id: int
    sku: str
    barcode: str | None = None
    name: str
    brand: str | None = None
    category: str
    storage_type: str
    default_unit: str
    image_url: str | None = None


class ProductCreate(BaseModel):
    sku: str
    name: str
    category: str
    storage_type: str
    default_unit: str
    barcode: str | None = None
    brand: str | None = None
    image_url: str | None = None
