"""Store Firebase Installation IDs alongside legacy FCM tokens."""

from alembic import op
import sqlalchemy as sa

revision = "20261027_01"
down_revision = "20261026_01"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("device_tokens") as batch_op:
        batch_op.add_column(sa.Column("fid", sa.Text(), nullable=True))
        batch_op.alter_column(
            "fcm_token",
            existing_type=sa.Text(),
            nullable=True,
        )


def downgrade() -> None:
    op.execute(sa.text("DELETE FROM device_tokens WHERE fcm_token IS NULL"))
    with op.batch_alter_table("device_tokens") as batch_op:
        batch_op.drop_column("fid")
        batch_op.alter_column(
            "fcm_token",
            existing_type=sa.Text(),
            nullable=False,
        )
