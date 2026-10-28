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
    issued_at_wib: str
    blockchain_status: str
    certificate_tx_hash: str | None = None
    block_number: int | None = None
    explorer_url: str | None = None


class BlockchainVerifyResponse(BaseModel):
    tx_hash: str
    verified: bool
    status: str
    block_number: int | None = None
    network: str = "BOT Chain Testnet"
    contract_address: str
    block_explorer_url: str
    verified_at: str | None = None
    certificate_hash_on_chain: str | None = None


class DonationListItem(BaseModel):
    id: int
    certificate_no: str
    listing_id: int
    product_name: str
    grade: str
    blockchain_status: str
    created_at: str
    carbon_saved_kg: float
    qty_diverted: int
    offtaker_name: str
    certificate_tx_hash: str | None = None
    block_number: int | None = None


class SellerDonationsResponse(BaseModel):
    items: list[DonationListItem]
    total_certificates: int
    total_carbon_saved_kg: float
