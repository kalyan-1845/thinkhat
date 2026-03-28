from typing import Dict, List, Optional, Any
from fastapi import WebSocket
import logging
import time
from database import db

logger = logging.getLogger(__name__)

class GroupManager:
    def __init__(self):
        # Memory caches (still useful for active connection management)
        self.active_connections: Dict[str, List[WebSocket]] = {}
        self.group_users: Dict[str, List[str]] = {}
        self.MAX_USERS = 20
        self.MAX_GROUP_AGE_SECONDS = 86400 # 24 HOURS

    async def connect(self, websocket: WebSocket, group_id: str, username: str) -> bool:
        """Attempt to add a user to a group. Persistent state is loaded from DB."""
        if group_id not in self.active_connections:
            self.active_connections[group_id] = []
            self.group_users[group_id] = []

        if len(self.active_connections[group_id]) >= self.MAX_USERS:
            logger.warning(f"Group {group_id} is full.")
            return False

        await websocket.accept()
        self.active_connections[group_id].append(websocket)
        self.group_users[group_id].append(username)
        return True

    def disconnect(self, websocket: WebSocket, group_id: str, username: str):
        if group_id in self.active_connections and websocket in self.active_connections[group_id]:
            self.active_connections[group_id].remove(websocket)
            if username in self.group_users[group_id]:
                self.group_users[group_id].remove(username)
            
            # Note: We don't wipe the DB on disconnect anymore because it's persistent!

    async def create_group(self, group_id: str, creator_username: str):
        metadata = {
            "group_id": group_id,
            "creator": creator_username,
            "created_at": time.time(),
        }
        await db.save_room(group_id, metadata)
        logger.info(f"Room {group_id} persisted in MongoDB by {creator_username}")

    async def update_node_position(self, group_id: str, message_id: str, x: float, y: float):
        # We fetch current first to avoid wiping others, although MongoDB $set is better
        current = await db.get_node_positions(group_id)
        current[message_id] = {"x": x, "y": y}
        await db.update_node_positions(group_id, current)

    async def get_node_positions(self, group_id: str) -> Dict[str, dict]:
        return await db.get_node_positions(group_id)

    async def destroy_group(self, group_id: str):
        # Broadcast destruction first
        if group_id in self.active_connections:
            destroy_msg = {"type": "system", "event": "room-destroyed"}
            for connection in list(self.active_connections[group_id]):
                try:
                    await connection.send_json(destroy_msg)
                    await connection.close()
                except: pass
        
        # We could delete from Mongo too if desired, but let's keep it for records unless user asked.
        # Clear memory
        if group_id in self.active_connections: del self.active_connections[group_id]
        if group_id in self.group_users: del self.group_users[group_id]

    async def group_exists(self, group_id: str) -> bool:
        room = await db.get_room(group_id)
        return room is not None

    async def add_to_history(self, group_id: str, message: dict):
        # Pop _id if it exists to be safe
        message.pop("_id", None)
        await db.save_message(group_id, message)

    async def get_history(self, group_id: str) -> List[dict]:
        return await db.get_messages(group_id)

    async def broadcast(self, message: dict, group_id: str):
        if group_id in self.active_connections:
            for connection in list(self.active_connections[group_id]):
                try:
                    await connection.send_json(message)
                except: pass

    def get_users_in_group(self, group_id: str) -> List[str]:
        return self.group_users.get(group_id, [])

    async def get_message_by_id(self, group_id: str, message_id: str) -> Optional[dict]:
        """Fetch a single message from MongoDB for the AI Expansion logic."""
        history = await self.get_history(group_id)
        for msg in history:
            if msg.get('id') == message_id:
                return msg
        return None

group_manager = GroupManager()
