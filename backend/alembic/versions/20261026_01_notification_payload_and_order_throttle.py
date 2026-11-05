"""Store notification navigation payloads and per-order notification throttle."""

from alembic import op
import sqlalchemy as sa

revision = "20261026_01"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "notifications",
        sa.Column("data", sa.JSON(), nullable=False, server_default=sa.text("'{}'")),
    )
    op.add_column("orders", sa.Column("last_notification_sent_at", sa.DateTime(timezone=True), nullable=True))


def downgrade() -> None:
    op.drop_column("orders", "last_notification_sent_at")
    op.drop_column("notifications", "data")
