import logging
from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger

from app.config import get_settings
from app.database import SessionLocal
from app.services.donation_service import (
    check_and_divert_expired_listings,
    retry_pending_blockchain_certificates,
)

logger = logging.getLogger(__name__)

scheduler = BackgroundScheduler()


def run_daily_esg_diversion_and_blockchain_sync():
    """
    Job harian (berjalan setiap pukul 09:00 WIB / 02:00 UTC):
    1. Memeriksa dan mengalihkan listing pangan yang sisa umurnya < 15 hari ke jalur donasi.
    2. Mencatat ulang donasi yang tx_hash blockchain-nya masih tertunda (retry).
    """
    logger.info("Running scheduled daily ESG diversion and blockchain sync...")
    db = SessionLocal()
    try:
        diverted = check_and_divert_expired_listings(db)
        logger.info("Scheduled task diverted %d expired listings to donation", len(diverted))

        retried = retry_pending_blockchain_certificates(db)
        logger.info("Scheduled task successfully retried %d pending blockchain records", retried)
    except Exception as e:
        logger.error("Error executing scheduled ESG diversion: %s", e)
    finally:
        db.close()


def start_scheduler():
    settings = get_settings()
    if settings.environment.lower() in {"test", "testing"}:
        logger.info("Skipping APScheduler in test environment")
        return

    if not scheduler.running:
        scheduler.add_job(
            run_daily_esg_diversion_and_blockchain_sync,
            trigger=CronTrigger(hour=2, minute=0, timezone="UTC"),
            id="daily_esg_diversion_sync",
            replace_existing=True,
        )
        scheduler.start()
        logger.info("APScheduler initialized for ESG diversion at 09:00 WIB (02:00 UTC)")


def shutdown_scheduler():
    if scheduler.running:
        scheduler.shutdown(wait=False)
        logger.info("APScheduler shut down")
