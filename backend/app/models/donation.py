from datetime import datetime, timezone
from sqlalchemy import (
    BigInteger,
    Column,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    Numeric,
    String,
)
from sqlalchemy.orm import relationship

from app.database import Base


class Offtaker(Base):
    __tablename__ = "offtakers"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    name = Column(String(150), nullable=False)
    type = Column(String(30), nullable=False)
    lat = Column(Float, nullable=False)
    lng = Column(Float, nullable=False)
    contact = Column(String(50), nullable=False)

    donations = relationship("Donation", back_populates="offtaker", cascade="all, delete-orphan")


class Donation(Base):
    __tablename__ = "donations"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    listing_id = Column(Integer, ForeignKey("listings.id", ondelete="CASCADE"), unique=True, nullable=False)
    offtaker_id = Column(Integer, ForeignKey("offtakers.id", ondelete="CASCADE"), nullable=False, index=True)
    grade = Column(String(1), nullable=False)
    qty_diverted = Column(Integer, nullable=False)
    carbon_saved_kg = Column(Numeric(10, 2), nullable=False)
    certificate_no = Column(String(50), unique=True, nullable=False, index=True)
    certificate_tx_hash = Column(String(66), nullable=True, index=True)
    block_number = Column(BigInteger, nullable=True)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)

    listing = relationship("Listing", back_populates="donation")
    offtaker = relationship("Offtaker", back_populates="donations")
