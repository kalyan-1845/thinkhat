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
        # Tracks rooms explicitly created by a "Create" flow
        self.created_groups: set = set()
        self.MAX_USERS = 20

    async def connect(self, websocket: WebSocket, group_id: str, username: str) -> bool:
        """Attempt to add a user to a group. Returns True if successful, False if full."""
        if group_id not in self.active_connections:
            self.active_connections[group_id] = []
            self.group_users[group_id] = []
            self.group_messages[group_id] = set()

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

            if len(self.active_connections[group_id]) == 0:
                logger.info(f"Group {group_id} is empty. Cleaning up session memory.")
                del self.active_connections[group_id]
                del self.group_users[group_id]
                del self.group_messages[group_id]
                if group_id in self.created_groups:
                    self.created_groups.remove(group_id)

    def create_group(self, group_id: str):
        self.created_groups.add(group_id)

    def group_exists(self, group_id: str) -> bool:
        return group_id in self.created_groups

    async def broadcast(self, message: dict, group_id: str):
        """Broadcast JSON message to all clients in group_id."""
        if group_id in self.active_connections:
            # Create a copy to iterate safely in case connections drop mid-broadcast
            for connection in list(self.active_connections[group_id]):
                try:
                    await connection.send_json(message)
                except Exception as e:
                    logger.error(f"Error broadcasting to a client in {group_id}: {e}")

    def get_users_in_group(self, group_id: str) -> List[str]:
        return self.group_users.get(group_id, [])

    def register_message_and_check_duplicate_ai(self, group_id: str, message_id: str) -> bool:
        """
        Registers the AI message to prevent duplicate processing.
        Returns True if it's the first time we see this AI request, False if already processing/processed.
        """
        if group_id not in self.group_messages:
            return False
            
        if message_id in self.group_messages[group_id]:
            return False
            
        self.group_messages[group_id].add(message_id)
        return True

group_manager = GroupManager()
