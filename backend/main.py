from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from websocket import router as websocket_router
from group_manager import group_manager
from utils import generate_group_id, is_valid_username
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="Real-Time Collaborative API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # Since we're doing an MVP, allow all
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

import asyncio
import time

app.include_router(websocket_router)

@app.on_event("startup")
async def startup_event():
    asyncio.create_task(cleanup_expired_groups())

async def cleanup_expired_groups():
    while True:
        await asyncio.sleep(3600) # Check every hour
        now = time.time()
        expired = []
        for gid, created_at in group_manager.group_creation_times.items():
            if now - created_at > group_manager.MAX_GROUP_AGE_SECONDS:
                expired.append(gid)
        
        for gid in expired:
            logger.info(f"Cleaning up expired room: {gid}")
            # Use a dummy websocket to trigger group_manager.disconnect cleanup logic
            # or just manually delete entries. Let's manually delete for safety.
            if gid in group_manager.active_connections: del group_manager.active_connections[gid]
            if gid in group_manager.group_users: del group_manager.group_users[gid]
            if gid in group_manager.group_messages: del group_manager.group_messages[gid]
            if gid in group_manager.group_history: del group_manager.group_history[gid]
            if gid in group_manager.group_creation_times: del group_manager.group_creation_times[gid]
            if gid in group_manager.created_groups: group_manager.created_groups.remove(gid)

@app.get("/")
async def root():
    return {"message": "Welcome to the Real-Time Backend API"}

@app.get("/health")
async def health_check():
    """Simple health checking endpoint."""
    return {"status": "ok", "active_groups": len(group_manager.active_connections)}

@app.post("/group/generate")
async def prepare_group(pattern: str, username: str, mode: str = "join"):
    """
    Generate a deterministic group string from a text pattern.
    The client hashes this and uses it as the group_id in the WS path.
    """
    if not pattern:
        raise HTTPException(status_code=400, detail="Pattern cannot be empty.")
    
    group_id = generate_group_id(pattern)
    
    if mode == "create":
        group_manager.create_group(group_id, username)
    else:
        if not group_manager.group_exists(group_id):
            raise HTTPException(status_code=404, detail="Room not found. Pattern incorrect or room expired.")

    return {
        "pattern": pattern, 
        "group_id": group_id, 
        "is_creator": mode == "create"
    }

@app.post("/group/{group_id}/destroy")
async def destroy_room(group_id: str, username: str):
    """Allow the creator to wipe the room and kick all users."""
    creator = group_manager.group_creators.get(group_id)
    if not creator or creator != username:
        raise HTTPException(status_code=403, detail="Only the creator can destroy the room.")
    
    await group_manager.destroy_group(group_id)
    return {"message": "Room destroyed successfully"}

@app.post("/config")
async def update_config(groq_key: Optional[str] = None, openai_key: Optional[str] = None):
    """Dynamically update AI API keys for the current session."""
    import os
    if groq_key:
        os.environ["GROQ_API_KEY"] = groq_key
        # Also update the router's local copy if it has one
        from ai_router import AIRouter
        # Assuming ai_router is global, but the module re-reads os.environ in getAIResponse
        logger.info("Updated Groq API Key")
    if openai_key:
        os.environ["OPENAI_API_KEY"] = openai_key
        logger.info("Updated OpenAI API Key")
    return {"message": "Config updated successfully"}

@app.get("/group/{group_id}/users")
async def get_group_users(group_id: str):
    users = group_manager.get_users_in_group(group_id)
    return {"group_id": group_id, "user_count": len(users), "users": users}
