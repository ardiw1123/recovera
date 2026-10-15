from pydantic import BaseModel, Field


class FeedbackRequest(BaseModel):
    kesan: str = Field(min_length=1, description="Kesan selama perkuliahan PAM")
    saran: str = Field(min_length=1, description="Saran perbaikan untuk mata kuliah PAM")


class FeedbackResponse(BaseModel):
    id: int
    user_id: int
    kesan: str
    saran: str
    submitted_at: str
