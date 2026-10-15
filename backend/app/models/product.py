from sqlalchemy import Column, Integer, String, Text
from sqlalchemy.orm import relationship

from app.database import Base


class Product(Base):
    __tablename__ = "products"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    sku = Column(String(50), unique=True, nullable=False, index=True)
    barcode = Column(String(50), nullable=True, index=True)
    name = Column(String(150), nullable=False, index=True)
    brand = Column(String(100), nullable=True)
    category = Column(String(50), nullable=False, index=True)
    storage_type = Column(String(20), nullable=False)
    default_unit = Column(String(20), nullable=False)
    image_url = Column(Text, nullable=True)

    listings = relationship("Listing", back_populates="product", cascade="all, delete-orphan")
