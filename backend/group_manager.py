from typing import Dict, List, Optional
from fastapi import WebSocket
import logging

logger = logging.getLogger(__name__)

class GroupManager:
    def __init__(self):
        # Maps group_id -> list of active WebSocket connections
        self.active_connections: Dict[str, List[WebSocket]] = {}
        # Maps group_id -> list of usernames currently in the group
        self.group_users: Dict[str, List[str]] = {}
        # Maps group_id -> message_id set (for AI locking and generic deduplication)
        self.group_messages: Dict[str, set] = {}
        # TRACKS WHO CREATED EACH GROUP
        self.group_creators: Dict[str, str] = {}
        # TRACKS WHEN EACH GROUP WAS CREATED
        self.group_creation_times: Dict[str, float] = {}
        # Tracks rooms explicitly created by a "Create" flow
        self.created_groups: set = set()
        # Message history stored per group
        self.group_history: Dict[str, List[dict]] = {}
        # TRACKS X/Y POSITIONS FOR MIND MAP: group_id -> {msg_id: {"x": float, "y": float}}
        self.group_node_positions: Dict[str, Dict[str, dict]] = {}
        self.MAX_USERS = 20
        self.MAX_GROUP_AGE_SECONDS = 86400 # 24 HOURS LIMIT

    async def connect(self, websocket: WebSocket, group_id: str, username: str) -> bool:
        """Attempt to add a user to a group. Returns True if successful, False if full."""
        if group_id not in self.active_connections:
            self.active_connections[group_id] = []
            self.group_users[group_id] = []
            self.group_messages[group_id] = set()
            self.group_history[group_id] = []

        if len(self.active_connections[group_id]) >= self.MAX_USERS:
            logger.warning(f"Group {group_id} is full. Rejecting user {username}.")
            return False

        await websocket.accept()
        self.active_connections[group_id].append(websocket)
        self.group_users[group_id].append(username)
        logger.info(f"User {username} joined group {group_id}.")
        return True

    def disconnect(self, websocket: WebSocket, group_id: str, username: str):
        """Remove a user from their active group and cleanup empty groups."""
        if group_id in self.active_connections and websocket in self.active_connections[group_id]:
            self.active_connections[group_id].remove(websocket)
            if username in self.group_users[group_id]:
                self.group_users[group_id].remove(username)
            logger.info(f"User {username} left group {group_id}.")

            # If room is empty, clean it up
            if len(self.active_connections[group_id]) == 0:
                self._wipe_group(group_id)

    def _wipe_group(self, group_id: str):
        """Internal helper to completely wipe a group from memory."""
        logger.info(f"Cleaning up room storage: {group_id}")
        if group_id in self.active_connections: del self.active_connections[group_id]
        if group_id in self.group_users: del self.group_users[group_id]
        if group_id in self.group_messages: del self.group_messages[group_id]
        if group_id in self.group_history: del self.group_history[group_id]
        if group_id in self.group_node_positions: del self.group_node_positions[group_id]
        if group_id in self.group_creation_times: del self.group_creation_times[group_id]
        if group_id in self.group_creators: del self.group_creators[group_id]
        if group_id in self.created_groups: self.created_groups.remove(group_id)

    def create_group(self, group_id: str, creator_username: str):
        import time
        self.created_groups.add(group_id)
        self.group_creators[group_id] = creator_username
        self.group_creation_times[group_id] = time.time()
        self.group_history[group_id] = []
        self.group_node_positions[group_id] = {}
        logger.info(f"Room {group_id} explicitly created by {creator_username}")

    def update_node_position(self, group_id: str, message_id: str, x: float, y: float):
        if group_id not in self.group_node_positions:
            self.group_node_positions[group_id] = {}
        self.group_node_positions[group_id][message_id] = {"x": x, "y": y}

    def get_node_positions(self, group_id: str) -> Dict[str, dict]:
        return self.group_node_positions.get(group_id, {})

    async def destroy_group(self, group_id: str):
        """Broadcast a destruction notice, then wipe the group's data."""
        if group_id in self.active_connections:
            destroy_msg = {
                "type": "system",
                "event": "room-destroyed",
                "message": "The creator has closed this room and wiped the data."
            }
            # Notify everyone and close their sockets
            for connection in list(self.active_connections[group_id]):
                try:
                    await connection.send_json(destroy_msg)
                    await connection.close()
                except:
                    pass
            
            self._wipe_group(group_id)

    def group_exists(self, group_id: str) -> bool:
        return group_id in self.created_groups

    def add_to_history(self, group_id: str, message: dict):
        if group_id in self.group_history:
            self.group_history[group_id].append(message)

    def get_history(self, group_id: str) -> List[dict]:
        return self.group_history.get(group_id, [])

    async def broadcast(self, message: dict, group_id: str):
        """Broadcast JSON message to all clients in group_id."""
        if group_id in self.active_connections:
            for connection in list(self.active_connections[group_id]):
                try:
                    await connection.send_json(message)
                except Exception as e:
                    logger.error(f"Error broadcasting to a client in {group_id}: {e}")

    def get_users_in_group(self, group_id: str) -> List[str]:
        return self.group_users.get(group_id, [])

    def register_message_and_check_duplicate_ai(self, group_id: str, message_id: str) -> bool:
        if group_id not in self.group_messages:
            return False
        if message_id in self.group_messages[group_id]:
            return False
        self.group_messages[group_id].add(message_id)
        return True

group_manager = GroupManager()
