import os
from motor.motor_asyncio import AsyncIOMotorClient
from typing import List, Dict, Any, Optional

MONGO_URI = "mongodb+srv://prsnlkalyan_db_user:ZMUJAzjk2JK6pJ03@cluster0.phbbtix.mongodb.net/?retryWrites=true&w=majority&appName=Cluster0"
DB_NAME = "flowconnect_db"

class Database:
    client: AsyncIOMotorClient = None
    db = None

    @classmethod
    async def connect_to_mongo(cls):
        """Initialize connection to Atlas."""
        cls.client = AsyncIOMotorClient(MONGO_URI)
        cls.db = cls.client[DB_NAME]
        print(f"Connected to MongoDB: {DB_NAME}")

    @classmethod
    async def close_mongo_connection(cls):
        """Cleanly close connection."""
        if cls.client:
            cls.client.close()
            print("MongoDB connection closed.")

    async def save_message(self, group_id: str, message: Dict[str, Any]):
        """Save a chat message or AI response."""
        collection = self.db[f"messages_{group_id}"]
        await collection.insert_one(message)

    async def get_messages(self, group_id: str, limit: int = 100) -> List[Dict[str, Any]]:
        """Fetch message history for a group."""
        collection = self.db[f"messages_{group_id}"]
        cursor = collection.find({}).sort("timestamp", 1).limit(limit)
        messages = await cursor.to_list(length=limit)
        # Remove _id for JSON serialization
        for msg in messages:
            msg.pop("_id", None)
        return messages

    async def save_room(self, group_id: str, metadata: Dict[str, Any]):
        """Save room creation info."""
        collection = self.db["rooms"]
        await collection.update_one(
            {"group_id": group_id},
            {"$set": metadata},
            upsert=True
        )

    async def get_room(self, group_id: str) -> Optional[Dict[str, Any]]:
        collection = self.db["rooms"]
        return await collection.find_one({"group_id": group_id})

    async def update_node_positions(self, group_id: str, positions: Dict[str, Any]):
        """Save mind map layout."""
        collection = self.db["node_positions"]
        await collection.update_one(
            {"group_id": group_id},
            {"$set": {"positions": positions}},
            upsert=True
        )

    async def get_node_positions(self, group_id: str) -> Dict[str, Any]:
        collection = self.db["node_positions"]
        doc = await collection.find_one({"group_id": group_id})
        return doc["positions"] if doc else {}

db = Database()
