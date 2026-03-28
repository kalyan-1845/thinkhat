import os
import jwt
from datetime import datetime, timedelta
from typing import Optional, Dict
from dotenv import load_dotenv
from fastapi import HTTPException, Depends, Security
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

load_dotenv()

# Use the secret from environment variables or a fallback for development
JWT_SECRET = os.getenv("JWT_SECRET", "supersecretkey")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 1440 # 24 HOURS

auth_scheme = HTTPBearer()

class AuthHandler:
    def create_access_token(self, data: Dict[str, str], expires_delta: Optional[timedelta] = None):
        """Generate a new JWT for the user."""
        to_encode = data.copy()
        if expires_delta:
            expire = datetime.utcnow() + expires_delta
        else:
            expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
        to_encode.update({"exp": expire})
        encoded_jwt = jwt.encode(to_encode, JWT_SECRET, algorithm=ALGORITHM)
        return encoded_jwt

    def decode_token(self, token: str) -> Dict[str, str]:
        """Verify the JWT and return payload."""
        try:
            payload = jwt.decode(token, JWT_SECRET, algorithms=[ALGORITHM])
            return payload
        except jwt.ExpiredSignatureError:
            raise HTTPException(status_code=401, detail="Token has expired")
        except jwt.InvalidTokenError:
            raise HTTPException(status_code=401, detail="Invalid token")

    async def get_current_user(self, auth: HTTPAuthorizationCredentials = Security(auth_scheme)):
        """FastAPI dependency to protect routes."""
        return self.decode_token(auth.credentials)

auth_handler = AuthHandler()
