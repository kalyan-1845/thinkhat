from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Query
from typing import Optional
import json
import logging
from group_manager import group_manager
from auth import auth_handler
from models import ChatMessage, AIResponse, SignalingMessage
import ai_router

router = APIRouter()
logger = logging.getLogger(__name__)

async def get_token_user(token: str) -> Optional[str]:
    """Helper to decode JWT from WS query or protocol."""
    try:
        payload = auth_handler.decode_token(token)
        return payload.get("sub")
    except:
        return None

@router.websocket("/ws/{group_id}/{username}")
async def websocket_endpoint(
    websocket: WebSocket, 
    group_id: str, 
    username: str,
    token: Optional[str] = Query(None)
):
    """
    Main WebSocket for real-time Sync.
    Now requires a valid 'token' query parameter for JWT Auth.
    """
    # 1. VERIFY JWT
    if not token:
        logger.warning("WebSocket attempt without token.")
        await websocket.close(code=4001) # Unauthorized
        return

    authenticated_user = await get_token_user(token)
    if not authenticated_user or authenticated_user != username:
        logger.warning(f"Auth failed for WS user {username}")
        await websocket.close(code=4002) # Forbidden
        return

    # 2. CONNECT
    success = await group_manager.connect(websocket, group_id, username)
    if not success:
        await websocket.close(code=4003) # Group full
        return

    try:
        # 3. INITIAL STATE PERSISTENCE
        # Send history (from MongoDB)
        history = await group_manager.get_history(group_id)
        if history:
            await websocket.send_json({
                "type": "system",
                "event": "initial-history",
                "messages": history
            })

        # Send node positions (from MongoDB)
        positions = await group_manager.get_node_positions(group_id)
        if positions:
             await websocket.send_json({
                "type": "system",
                "event": "initial-node-positions",
                "positions": positions
            })

        # 4. MESSAGE LOOP
        while True:
            data = await websocket.receive_text()
            message_data = json.loads(data)
            msg_type = message_data.get("type")

            if msg_type == "chat":
                msg = ChatMessage(**message_data)
                # Save to Persistent History (MongoDB)
                await group_manager.add_to_history(group_id, msg.model_dump())
                # Broadcast
                await group_manager.broadcast(msg.model_dump(), group_id)

            elif msg_type == "node_position_update":
                # Persist to Mind Map State (MongoDB)
                await group_manager.update_node_position(
                    group_id, 
                    message_data["messageId"], 
                    message_data["x"], 
                    message_data["y"]
                )
                # Broadcast
                await group_manager.broadcast(message_data, group_id)

            elif msg_type == "ask_ai":
                # AI Expansion with Persistence
                message_to_ask = await group_manager.get_message_by_id(group_id, message_data["messageId"])
                if message_to_ask:
                    msg_text = message_to_ask.get("text", "")
                    reply_text = await ai_router.getAIResponse(msg_text)
                    
                    from uuid import uuid4
                    import time
                    ai_resp = AIResponse(
                        id=str(uuid4()),
                        timestamp=int(time.time()),
                        messageId=message_data["messageId"],
                        aiReply=reply_text,
                        parent_text=msg_text,
                        parent_user=message_to_ask.get("user")
                    )
                    # Persist AI Response
                    await group_manager.add_to_history(group_id, ai_resp.model_dump())
                    # Broadcast
                    await group_manager.broadcast(ai_resp.model_dump(), group_id)

            elif msg_type == "webrtc_signaling":
                # Real-time signaling (don't persist to DB usually)
                await group_manager.broadcast(message_data, group_id)

    except WebSocketDisconnect:
        group_manager.disconnect(websocket, group_id, username)
        await group_manager.broadcast({
            "type": "system",
            "event": "user-left",
            "user": username
        }, group_id)
    except Exception as e:
        logger.error(f"WebSocket Loop Error in group {group_id}: {e}")
