from pydantic import BaseModel, Field
from typing import Optional, Any, Dict

class MessageBase(BaseModel):
    id: str
    type: str # 'chat', 'ai_response', 'webrtc_signaling'
    timestamp: int

class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"

class LoginRequest(BaseModel):
    username: str

class ChatMessage(MessageBase):
    type: str = 'chat'
    text: str
    user: str
    aiUsed: bool = False
    parent_text: Optional[str] = None
    parent_user: Optional[str] = None

class AIResponse(MessageBase):
    type: str = 'ai_response'
    messageId: str
    aiReply: str
    parent_text: Optional[str] = None # For quoted reply rendering
    parent_user: Optional[str] = None

class SignalingMessage(MessageBase):
    type: str = 'webrtc_signaling'
    event: str # 'user-joined-voice', 'offer', 'answer', 'ice-candidate', 'user-left-voice'
    data: Optional[Dict[str, Any]] = None
    user: str

class UserSession(BaseModel):
    user_id: str
    username: str

class GroupSession(BaseModel):
    group_id: str
    users: list[UserSession] = []
    messages: list[ChatMessage] = []

class RoomRequest(BaseModel):
    pattern: str
    username: str
    mode: str = "join"
