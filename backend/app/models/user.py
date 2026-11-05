from datetime import datetime, timezone
from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    Numeric,
    String,
    Text,
)
from sqlalchemy.dialects.sqlite import JSON as SQLITE_JSON
from sqlalchemy.orm import relationship

from app.database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    email = Column(String(255), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    role = Column(String(20), nullable=False)
    name = Column(String(100), nullable=False)
    phone = Column(String(20), nullable=True)
    photo_url = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)

    seller = relationship("Seller", back_populates="user", uselist=False, cascade="all, delete-orphan")
    buyer = relationship("Buyer", back_populates="user", uselist=False, cascade="all, delete-orphan")
    refresh_tokens = relationship("RefreshToken", back_populates="user", cascade="all, delete-orphan")
    device_tokens = relationship("DeviceToken", back_populates="user", cascade="all, delete-orphan")
    notifications = relationship("Notification", back_populates="user", cascade="all, delete-orphan")
    course_feedbacks = relationship("CourseFeedback", back_populates="user", cascade="all, delete-orphan")


class Seller(Base):
    __tablename__ = "sellers"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), unique=True, nullable=False)
    company_name = Column(String(150), nullable=False)
    address = Column(Text, nullable=False)
    warehouse_lat = Column(Float, nullable=False)
    warehouse_lng = Column(Float, nullable=False)
    city = Column(String(100), nullable=False)

    user = relationship("User", back_populates="seller")
    listings = relationship("Listing", back_populates="seller", cascade="all, delete-orphan")


class Buyer(Base):
    __tablename__ = "buyers"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), unique=True, nullable=False)
    business_type = Column(String(50), nullable=False)
    address = Column(Text, nullable=False)
    base_lat = Column(Float, nullable=False)
    base_lng = Column(Float, nullable=False)
    pref_categories = Column(SQLITE_JSON, nullable=False, default=list)
    max_radius_km = Column(Integer, default=15, nullable=False)
    has_cold_storage = Column(Boolean, default=False, nullable=False)
    total_orders_completed = Column(Integer, default=0, nullable=False)
    payment_reliability_score = Column(Numeric(3, 2), default=1.00, nullable=False)

    user = relationship("User", back_populates="buyer")
    offers = relationship("Offer", back_populates="buyer", cascade="all, delete-orphan")
    orders = relationship("Order", back_populates="buyer", cascade="all, delete-orphan")


class RefreshToken(Base):
    __tablename__ = "refresh_tokens"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    token_hash = Column(String(255), nullable=False, index=True)
    expires_at = Column(DateTime(timezone=True), nullable=False)
    is_revoked = Column(Boolean, default=False, nullable=False)

    user = relationship("User", back_populates="refresh_tokens")


class DeviceToken(Base):
    __tablename__ = "device_tokens"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    fcm_token = Column(Text, nullable=True)
    fid = Column(Text, nullable=True)
    updated_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)

    user = relationship("User", back_populates="device_tokens")
