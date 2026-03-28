from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from group_manager import group_manager
from models import ChatMessage, AIResponse, SignalingMessage
from ai_router import ai_router
import json
import logging
import asyncio
import time
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
        # Send existing history to the newly connected user
        for history_msg in group_manager.get_history(group_id):
            try:
                await websocket.send_json(history_msg)
            except Exception as e:
                logger.error(f"Failed to send history to {username}: {e}")

        # Send initial node positions
        positions = group_manager.get_node_positions(group_id)
        if positions:
            await websocket.send_json({
                "type": "system",
                "event": "initial-node-positions",
                "positions": positions
            })

        # Broadcast user joined event (system message)
        join_msg = {
            "type": "system",
            "event": "user-joined",
            "user": username,
            "timestamp": int(time.time())
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
                    # Store in memory history
                    group_manager.add_to_history(group_id, chat_msg.model_dump())
                    # Broadcast to everyone in group
                    await group_manager.broadcast(chat_msg.model_dump(), group_id)

                elif msg_type == "ask_ai":
                    message_id = msg_data.get("messageId")
                    if message_id:
                        history = group_manager.get_history(group_id)
                        target_msg = next((m for m in history if m.get("id") == message_id and m.get("type") == "chat"), None)
                        
                        if target_msg and not target_msg.get("aiUsed", False):
                            # Ensure we don't process this multiple times across clients
                            first_time = group_manager.register_message_and_check_duplicate_ai(group_id, message_id)
                            
                            if first_time:
                                # Mark as used in server memory
                                target_msg["aiUsed"] = True
                                # Start background task to call AI
                                temp_chat_msg = ChatMessage(**target_msg)
                                asyncio.create_task(process_ai_response(temp_chat_msg, group_id))

                elif msg_type == "node_position_update":
                    # Update local memory
                    group_manager.update_node_position(
                        group_id, 
                        msg_data.get("messageId"), 
                        float(msg_data.get("x")), 
                        float(msg_data.get("y"))
                    )
                    # Broadcast to others
                    await group_manager.broadcast(msg_data, group_id)

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
            "timestamp": int(time.time())
        }
        await group_manager.broadcast(leave_msg, group_id)


async def process_ai_response(incoming_msg: ChatMessage, group_id: str):
    """Handles routing the message text to the AI and broadcasting the result."""
    reply_text = await ai_router.getAIResponse(incoming_msg.text)
    
    ai_resp = AIResponse(
        id=f"ai_{incoming_msg.id}",
        timestamp=int(time.time()),
        messageId=incoming_msg.id,
        aiReply=reply_text
    )
    
    group_manager.add_to_history(group_id, ai_resp.model_dump())
    await group_manager.broadcast(ai_resp.model_dump(), group_id)
