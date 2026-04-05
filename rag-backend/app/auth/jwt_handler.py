class JWTHandler:
    """JWT token creation and validation - stub implementation."""

    @staticmethod
    def create_access_token(data: dict) -> str:
        raise NotImplementedError

    @staticmethod
    def verify_token(token: str) -> dict:
        raise NotImplementedError
