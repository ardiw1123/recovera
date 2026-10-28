import json
import logging
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from web3 import Web3
from web3.exceptions import Web3Exception

from app.config import get_settings

logger = logging.getLogger(__name__)

ABI_PATH = Path(__file__).resolve().parent.parent.parent / "contracts" / "abi" / "ESGCertificateRegistry.json"

_cached_abi = None


def get_contract_abi() -> list[dict[str, Any]]:
    global _cached_abi
    if _cached_abi is None:
        if not ABI_PATH.exists():
            raise FileNotFoundError(f"Smart contract ABI not found at {ABI_PATH}")
        with open(ABI_PATH, "r", encoding="utf-8") as f:
            _cached_abi = json.load(f)
    return _cached_abi


def get_web3_client() -> Web3:
    settings = get_settings()
    rpc_url = settings.bot_chain_rpc_url
    return Web3(Web3.HTTPProvider(rpc_url))


def get_contract(w3: Web3 | None = None):
    if w3 is None:
        w3 = get_web3_client()
    settings = get_settings()
    contract_address = settings.bot_chain_contract_address
    if not contract_address:
        raise ValueError("BOT_CHAIN_CONTRACT_ADDRESS is not configured")
    abi = get_contract_abi()
    return w3.eth.contract(address=Web3.to_checksum_address(contract_address), abi=abi)


def store_certificate_on_chain(certificate_no: str, cert_data_hash: str) -> dict[str, Any]:
    """
    Menyimpan hash data sertifikat ke blockchain BOT Chain via akun Relayer backend.
    Mengembalikan dict: { 'tx_hash': str, 'block_number': int, 'status': 'success' | 'failed' }
    """
    settings = get_settings()
    private_key = settings.bot_chain_private_key
    if not private_key:
        logger.error("BOT_CHAIN_PRIVATE_KEY is not configured")
        return {"status": "failed", "error": "Relayer private key not configured"}

    if not settings.bot_chain_contract_address:
        logger.error("BOT_CHAIN_CONTRACT_ADDRESS is not configured")
        return {"status": "failed", "error": "Contract address not configured"}

    try:
        w3 = get_web3_client()
        if not w3.is_connected():
            logger.error("Cannot connect to BOT Chain RPC: %s", settings.bot_chain_rpc_url)
            return {"status": "failed", "error": "Cannot connect to blockchain RPC"}

        contract = get_contract(w3)
        acct = w3.eth.account.from_key(private_key)

        # Siapkan cert_hash dalam format bytes32
        if isinstance(cert_data_hash, str):
            if cert_data_hash.startswith("0x") and len(cert_data_hash) == 66:
                cert_hash_bytes = bytes.fromhex(cert_data_hash[2:])
            else:
                cert_hash_bytes = Web3.keccak(text=cert_data_hash)
        elif isinstance(cert_data_hash, bytes):
            cert_hash_bytes = cert_data_hash
        else:
            cert_hash_bytes = Web3.keccak(text=str(cert_data_hash))

        # Cek apakah sertifikat sudah pernah dicatat di contract
        try:
            existing = contract.functions.getHash(certificate_no).call()
            if existing and existing != b"\x00" * 32:
                logger.info("Certificate %s already exists on-chain", certificate_no)
                return {
                    "tx_hash": None,
                    "block_number": None,
                    "status": "already_exists",
                }
        except Exception:
            pass

        # Periksa saldo relayer untuk gas fee
        balance = w3.eth.get_balance(acct.address)
        gas_price = w3.eth.gas_price
        estimated_gas = 80000
        try:
            tx_draft = contract.functions.storeHash(certificate_no, cert_hash_bytes).build_transaction({
                "chainId": settings.bot_chain_chain_id,
                "from": acct.address,
                "nonce": w3.eth.get_transaction_count(acct.address),
                "gasPrice": gas_price,
            })
            estimated_gas = w3.eth.estimate_gas(tx_draft)
        except Exception as e:
            logger.warning("Gas estimation failed, using default %s: %s", estimated_gas, e)

        gas_limit = int(estimated_gas * 1.3)
        cost = gas_limit * gas_price
        if balance < cost:
            logger.error(
                "Insufficient gas for relayer %s. Balance: %s, Required: %s",
                acct.address,
                balance,
                cost,
            )
            return {"status": "failed", "error": "Insufficient gas balance on relayer"}

        tx = contract.functions.storeHash(certificate_no, cert_hash_bytes).build_transaction({
            "chainId": settings.bot_chain_chain_id,
            "from": acct.address,
            "nonce": w3.eth.get_transaction_count(acct.address),
            "gas": gas_limit,
            "gasPrice": gas_price,
        })

        signed = w3.eth.account.sign_transaction(tx, private_key)
        raw_tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
        tx_hash_hex = raw_tx_hash.hex()
        if not tx_hash_hex.startswith("0x"):
            tx_hash_hex = f"0x{tx_hash_hex}"

        receipt = w3.eth.wait_for_transaction_receipt(raw_tx_hash, timeout=60)
        is_success = receipt.status == 1

        return {
            "tx_hash": tx_hash_hex,
            "block_number": receipt.blockNumber,
            "status": "success" if is_success else "failed",
        }
    except Web3Exception as e:
        logger.error("Web3 error while storing certificate %s: %s", certificate_no, e)
        return {"status": "failed", "error": str(e)}
    except Exception as e:
        logger.error("Unexpected error while storing certificate %s: %s", certificate_no, e)
        return {"status": "failed", "error": str(e)}


def verify_certificate_on_chain(tx_hash: str) -> dict[str, Any]:
    """
    Memverifikasi transaksi sertifikat langsung ke blockchain BOT Chain dan smart contract.
    """
    settings = get_settings()
    explorer_base = settings.bot_chain_explorer_url.rstrip("/")
    block_explorer_url = f"{explorer_base}/tx/{tx_hash}"
    contract_addr = settings.bot_chain_contract_address

    if not tx_hash or not tx_hash.startswith("0x"):
        return {
            "tx_hash": tx_hash or "",
            "verified": False,
            "status": "Format hash transaksi tidak valid",
            "block_number": None,
            "network": "BOT Chain Testnet",
            "contract_address": contract_addr,
            "block_explorer_url": block_explorer_url,
            "verified_at": datetime.now(timezone.utc).isoformat(),
            "certificate_hash_on_chain": None,
        }

    try:
        w3 = get_web3_client()
        if not w3.is_connected():
            return {
                "tx_hash": tx_hash,
                "verified": False,
                "status": "Koneksi ke node blockchain gagal",
                "block_number": None,
                "network": "BOT Chain Testnet",
                "contract_address": contract_addr,
                "block_explorer_url": block_explorer_url,
                "verified_at": datetime.now(timezone.utc).isoformat(),
                "certificate_hash_on_chain": None,
            }

        try:
            receipt = w3.eth.get_transaction_receipt(tx_hash)
        except Exception as e:
            logger.info("Transaction receipt not found for %s: %s", tx_hash, e)
            return {
                "tx_hash": tx_hash,
                "verified": False,
                "status": "Transaksi tidak ditemukan di blockchain",
                "block_number": None,
                "network": "BOT Chain Testnet",
                "contract_address": contract_addr,
                "block_explorer_url": block_explorer_url,
                "verified_at": datetime.now(timezone.utc).isoformat(),
                "certificate_hash_on_chain": None,
            }

        is_confirmed = receipt.status == 1
        block_number = receipt.blockNumber

        # Cari event CertificateStored
        contract = get_contract(w3)
        cert_hash_on_chain = None
        try:
            events = contract.events.CertificateStored().process_receipt(receipt)
            if events:
                raw_hash = events[0]["args"]["certHash"]
                cert_hash_on_chain = raw_hash.hex()
                if not cert_hash_on_chain.startswith("0x"):
                    cert_hash_on_chain = f"0x{cert_hash_on_chain}"
        except Exception as e:
            logger.debug("Could not parse CertificateStored event: %s", e)

        # Dapatkan timestamp block jika memungkinkan
        verified_at = datetime.now(timezone.utc).isoformat()
        try:
            block = w3.eth.get_block(block_number)
            if block and "timestamp" in block:
                verified_at = datetime.fromtimestamp(block["timestamp"], tz=timezone.utc).isoformat()
        except Exception:
            pass

        return {
            "tx_hash": tx_hash,
            "verified": is_confirmed,
            "status": "Confirmed" if is_confirmed else "Failed",
            "block_number": block_number,
            "network": "BOT Chain Testnet",
            "contract_address": contract_addr,
            "block_explorer_url": block_explorer_url,
            "verified_at": verified_at,
            "certificate_hash_on_chain": cert_hash_on_chain,
        }
    except Exception as e:
        logger.error("Error verifying transaction %s: %s", tx_hash, e)
        return {
            "tx_hash": tx_hash,
            "verified": False,
            "status": f"Error verifikasi: {str(e)}",
            "block_number": None,
            "network": "BOT Chain Testnet",
            "contract_address": contract_addr,
            "block_explorer_url": block_explorer_url,
            "verified_at": datetime.now(timezone.utc).isoformat(),
            "certificate_hash_on_chain": None,
        }
