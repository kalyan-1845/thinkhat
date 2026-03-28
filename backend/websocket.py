from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from group_manager import group_manager
from models import ChatMessage, AIResponse, SignalingMessage
from ai_router import ai_router
import json
import logging
import asyncio
from typing import Optional

logger = logging.getLogger(__name__)

router = APIRouter()

@router.websocket("/ws/{group_id}/{username}")
async def websocket_endpoint(websocket: WebSocket, group_id: str, username: str):
    is_connected = await group_manager.connect(websocket, group_id, username)
    if not is_connected:
        await websocket.close(code=1000, reason="Group is full")
        return

    try:
        # Broadcast user joined event (system message)
        join_msg = {
            "type": "system",
            "event": "user-joined",
            "user": username,
            "timestamp": asyncio.get_event_loop().time()
        }
        await group_manager.broadcast(join_msg, group_id)

        while True:
            data = await websocket.receive_text()
            try:
                msg_data = json.loads(data)
                msg_type = msg_data.get("type")

                if msg_type == "chat":
                    # It's a regular chat message
                    chat_msg = ChatMessage(**msg_data)
                    # Broadcast to everyone in group
                    await group_manager.broadcast(chat_msg.model_dump(), group_id)

                    # Check for AI trigger
                    if chat_msg.aiUsed:
                        # Ensure we don't process this multiple times across clients
                        # Lock against message_id
                        first_time = group_manager.register_message_and_check_duplicate_ai(group_id, chat_msg.id)
                        
                        if first_time:
                            # Start background task to call AI
                            asyncio.create_task(process_ai_response(chat_msg, group_id))

                elif msg_type == "webrtc_signaling":
                    # Forward signaling message to EVERYONE (or ideally skip sender)
                    # WebRTC clients must look out for the exact event types.
                    sig_msg = SignalingMessage(**msg_data)
                    
                    # Instead of group_manager.broadcast which sends to all, we could specifically send only 
                    # to others if needed, but standard is to broadcast and let client ignore their own user
                    await group_manager.broadcast(sig_msg.model_dump(), group_id)

                else:
                    logger.warning(f"Unknown message type received: {msg_type}")

            except json.JSONDecodeError:
                logger.error("Invalid JSON received")
            except Exception as e:
                logger.error(f"Error processing message: {e}")

    except WebSocketDisconnect:
        # Handle cleanup
        group_manager.disconnect(websocket, group_id, username)
        
        # Broadcast user left event
        leave_msg = {
            "type": "system",
            "event": "user-left",
            "user": username,
            "timestamp": asyncio.get_event_loop().time()
        }
        await group_manager.broadcast(leave_msg, group_id)


async def process_ai_response(incoming_msg: ChatMessage, group_id: str):
    """Handles routing the message text to the AI and broadcasting the result."""
    try:
        reply_text = await ai_router.process_query(incoming_msg.text)
        
        ai_resp = AIResponse(
            id=f"ai_{incoming_msg.id}",
            timestamp=int(asyncio.get_event_loop().time()),
            messageId=incoming_msg.id,
            aiReply=reply_text
        )
        
        await group_manager.broadcast(ai_resp.model_dump(), group_id)
        
    except Exception as e:
        logger.error(f"Error in process_ai_response: {e}")
        error_resp = AIResponse(
            id=f"ai_error_{incoming_msg.id}",
            timestamp=int(asyncio.get_event_loop().time()),
            messageId=incoming_msg.id,
            aiReply="Sorry, the AI service encountered a critical error preventing a response."
        )
        await group_manager.broadcast(error_resp.model_dump(), group_id)
