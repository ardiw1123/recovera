import asyncio
import json
from unittest.mock import AsyncMock, MagicMock, patch
from app.schemas.ai import InvoiceOcrResponse
from app.services.ai_service import process_invoice_ocr


def test_process_invoice_ocr_fallback_when_no_api_key(monkeypatch):
    monkeypatch.setenv("GROQ_API_KEY", "")
    res = asyncio.run(process_invoice_ocr("dummy.jpg", b"dummycontent"))
    assert isinstance(res, InvoiceOcrResponse)
    assert res.fallback_used is True
    assert res.rejected is False
    assert res.rejection_reason is None
    assert len(res.parsed_items) == 2
    assert res.parsed_items[0].product_name == "Susu UHT Full Cream 1L"


def test_process_invoice_ocr_rejected_when_ai_detects_non_food(monkeypatch):
    monkeypatch.setenv("GROQ_API_KEY", "gsk_test_fake_key_123")

    mock_completion = MagicMock()
    mock_choice = MagicMock()
    mock_choice.message.content = json.dumps({
        "rejected": True,
        "rejection_reason": "Gambar yang dikirim bukan faktur atau produk pangan",
    })
    mock_completion.choices = [mock_choice]

    mock_client = MagicMock()
    mock_client.chat.completions.create = AsyncMock(return_value=mock_completion)

    with patch("app.services.ai_service.AsyncGroq", return_value=mock_client):
        res = asyncio.run(process_invoice_ocr("cat.jpg", b"fake_cat_bytes"))
        assert isinstance(res, InvoiceOcrResponse)
        assert res.rejected is True
        assert res.rejection_reason == "Gambar yang dikirim bukan faktur atau produk pangan"
        assert res.fallback_used is False
        assert len(res.parsed_items) == 0


def test_process_invoice_ocr_success_when_ai_detects_food(monkeypatch):
    monkeypatch.setenv("GROQ_API_KEY", "gsk_test_fake_key_123")

    mock_completion = MagicMock()
    mock_choice = MagicMock()
    mock_choice.message.content = json.dumps({
        "rejected": False,
        "supplier_name": "PT Pangan Sejahtera",
        "invoice_number": "INV-20261024-888",
        "items": [
            {
                "product_name": "Gula Pasir Kristal Putih 1kg",
                "brand": "Gulaku",
                "category": "Flour & Grain",
                "quantity": 50,
                "unit": "kg",
                "expiry_date": "2026-12-31",
                "normal_price": 18000.0,
                "confidence": 0.98,
            }
        ],
    })
    mock_completion.choices = [mock_choice]

    mock_client = MagicMock()
    mock_client.chat.completions.create = AsyncMock(return_value=mock_completion)

    with patch("app.services.ai_service.AsyncGroq", return_value=mock_client):
        res = asyncio.run(process_invoice_ocr("faktur.jpg", b"fake_invoice_bytes"))
        assert isinstance(res, InvoiceOcrResponse)
        assert res.rejected is False
        assert res.fallback_used is False
        assert res.supplier_name == "PT Pangan Sejahtera"
        assert len(res.parsed_items) == 1
        assert res.parsed_items[0].product_name == "Gula Pasir Kristal Putih 1kg"


def test_process_invoice_ocr_fallback_when_api_exception(monkeypatch):
    monkeypatch.setenv("GROQ_API_KEY", "gsk_test_fake_key_123")

    mock_client = MagicMock()
    mock_client.chat.completions.create = AsyncMock(side_effect=Exception("Connection timeout"))

    with patch("app.services.ai_service.AsyncGroq", return_value=mock_client):
        res = asyncio.run(process_invoice_ocr("faktur.jpg", b"fake_invoice_bytes"))
        assert isinstance(res, InvoiceOcrResponse)
        assert res.fallback_used is True
        assert res.rejected is False
        assert len(res.parsed_items) == 2
