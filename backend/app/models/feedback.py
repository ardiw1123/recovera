from datetime import datetime, timezone
from sqlalchemy import (
    Column,
    DateTime,
    ForeignKey,
    Integer,
    Text,
)
from sqlalchemy.orm import relationship

from app.database import Base


class CourseFeedback(Base):
    __tablename__ = "course_feedbacks"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    kesan = Column(Text, nullable=False)
    saran = Column(Text, nullable=False)
    submitted_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)

    user = relationship("User", back_populates="course_feedbacks")
