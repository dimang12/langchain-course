"""Fernet encryption for OAuth credentials.

Keys are read from settings.CREDENTIAL_ENCRYPTION_KEY. In dev, if no key is
configured, we generate an ephemeral one at import time — this means
encrypted rows will NOT survive a restart, which is fine for local dev
but must not happen in production.

Key format: base64-encoded 32 raw bytes. Generate with:
    python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
"""

from __future__ import annotations

import logging

from cryptography.fernet import Fernet, InvalidToken

from app.config import settings

logger = logging.getLogger(__name__)

_fernet: Fernet | None = None
_ephemeral_warned = False


def _get_fernet() -> Fernet:
    global _fernet, _ephemeral_warned
    if _fernet is not None:
        return _fernet

    key_str = (settings.CREDENTIAL_ENCRYPTION_KEY or "").strip()
    if key_str:
        try:
            _fernet = Fernet(key_str.encode())
            return _fernet
        except Exception as exc:
            logger.error("Invalid CREDENTIAL_ENCRYPTION_KEY: %s — generating ephemeral key", exc)

    if not _ephemeral_warned:
        logger.warning(
            "No CREDENTIAL_ENCRYPTION_KEY set — generating ephemeral key. "
            "Encrypted credentials will NOT survive server restart. "
            "Set CREDENTIAL_ENCRYPTION_KEY in .env for persistent storage."
        )
        _ephemeral_warned = True
    _fernet = Fernet(Fernet.generate_key())
    return _fernet


def encrypt(plaintext: str) -> str:
    if plaintext is None:
        raise ValueError("encrypt() requires a non-None string")
    return _get_fernet().encrypt(plaintext.encode("utf-8")).decode("utf-8")


def decrypt(ciphertext: str) -> str:
    if not ciphertext:
        return ""
    try:
        return _get_fernet().decrypt(ciphertext.encode("utf-8")).decode("utf-8")
    except InvalidToken:
        logger.warning("Failed to decrypt credential — likely ephemeral key rotation")
        return ""
