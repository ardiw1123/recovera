from datetime import date, datetime, timezone
from sqlalchemy import (
    Column,
    Date,
    DateTime,
    ForeignKey,
    Integer,
    Numeric,
    String,
)
from sqlalchemy.orm import relationship

from app.database import Base


class Listing(Base):
    __tablename__ = "listings"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    product_id = Column(Integer, ForeignKey("products.id", ondelete="CASCADE"), nullable=False, index=True)
    seller_id = Column(Integer, ForeignKey("sellers.id", ondelete="CASCADE"), nullable=False, index=True)
    batch_number = Column(String(50), nullable=False)
    qty = Column(Integer, nullable=False)
    normal_price = Column(Numeric(12, 2), nullable=False)
    start_price = Column(Numeric(12, 2), nullable=False)
    min_price = Column(Numeric(12, 2), nullable=False)
    drop_interval_minutes = Column(Integer, default=60, nullable=False)
    drop_percentage = Column(Numeric(4, 2), default=2.50, nullable=False)
    expiry_date = Column(Date, nullable=False, index=True)
    auction_start_at = Column(DateTime(timezone=True), nullable=False)
    auction_end_at = Column(DateTime(timezone=True), nullable=False)
    status = Column(String(20), default="active", nullable=False, index=True)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)

    product = relationship("Product", back_populates="listings")
    seller = relationship("Seller", back_populates="listings")
    offers = relationship("Offer", back_populates="listing", cascade="all, delete-orphan")
    orders = relationship("Order", back_populates="listing", cascade="all, delete-orphan")
    donation = relationship("Donation", back_populates="listing", uselist=False, cascade="all, delete-orphan")


class Offer(Base):
    __tablename__ = "offers"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    listing_id = Column(Integer, ForeignKey("listings.id", ondelete="CASCADE"), nullable=False, index=True)
    buyer_id = Column(Integer, ForeignKey("buyers.id", ondelete="CASCADE"), nullable=False, index=True)
    match_score = Column(Numeric(4, 3), nullable=False)
    distance_km = Column(Numeric(5, 2), nullable=False)
    days_to_expiry = Column(Integer, nullable=False)
    offered_discount_pct = Column(Numeric(4, 2), nullable=False)
    status = Column(String(20), default="sent", nullable=False)
    selection_source = Column(String(20), default="model", nullable=False)
    sent_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)
    responded_at = Column(DateTime(timezone=True), nullable=True)

    listing = relationship("Listing", back_populates="offers")
    buyer = relationship("Buyer", back_populates="offers")
