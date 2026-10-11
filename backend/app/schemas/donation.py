from pydantic import BaseModel


class CertificateCurrencyBreakdown(BaseModel):
    idr: float
    usd: float
    eur: float
    gbp: float


class CertificateResponse(BaseModel):
    id: int
    certificate_no: str
    listing_id: int
    product_name: str
    offtaker_name: str
    offtaker_type: str
    grade: str
    qty_diverted: int
    carbon_saved_kg: float
    monetary_value: CertificateCurrencyBreakdown
    issued_at_london: str
    certificate_tx_hash: str | None = None
    block_number: int | None = None


class BlockchainVerifyResponse(BaseModel):
    tx_hash: str
    verified: bool
    status: str
    block_number: int | None = None
    network: str = "BOT Chain Testnet"
    contract_address: str = "0x89205A3A3b2A69De6Dbf7f01ED13B2108B2c43e7"
    block_explorer_url: str
