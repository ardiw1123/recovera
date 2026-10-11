from datetime import datetime, timezone
from typing import Annotated
from fastapi import APIRouter, Body, status

from app.core.dependencies import CurrentUserDep, DbSessionDep
from app.models.feedback import CourseFeedback
from app.schemas.envelope import ResponseEnvelope, wrap_success
from app.schemas.feedback import FeedbackRequest, FeedbackResponse

router = APIRouter(prefix="/feedback", tags=["feedback"])


@router.post(
    "",
    status_code=status.HTTP_201_CREATED,
    response_model=ResponseEnvelope[FeedbackResponse],
)
async def submit_feedback(
    db: DbSessionDep,
    current_user: CurrentUserDep,
    payload: Annotated[FeedbackRequest, Body()],
) -> dict:
    feedback = CourseFeedback(
        user_id=current_user.id,
        kesan=payload.kesan,
        saran=payload.saran,
        submitted_at=datetime.now(timezone.utc),
    )
    db.add(feedback)
    db.commit()
    db.refresh(feedback)

    return wrap_success(
        FeedbackResponse(
            id=feedback.id,
            user_id=feedback.user_id,
            kesan=feedback.kesan,
            saran=feedback.saran,
            submitted_at=feedback.submitted_at.isoformat(),
        ).model_dump()
    )
