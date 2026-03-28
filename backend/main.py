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

app.include_router(websocket_router)

@app.get("/")
async def root():
    return {"message": "Welcome to the Real-Time Backend API"}

@app.get("/health")
async def health_check():
    """Simple health checking endpoint."""
    return {"status": "ok", "active_groups": len(group_manager.active_connections)}

@app.post("/group/generate")
async def prepare_group(pattern: str, mode: str = "join"):
    """
    Generate a deterministic group string from a text pattern.
    The client hashes this and uses it as the group_id in the WS path.
    """
    if not pattern:
        raise HTTPException(status_code=400, detail="Pattern cannot be empty.")
    
    group_id = generate_group_id(pattern)
    
    if mode == "create":
        group_manager.create_group(group_id)
    else:
        if not group_manager.group_exists(group_id):
            raise HTTPException(status_code=404, detail="Room not found. Pattern incorrect or room expired.")

    return {"pattern": pattern, "group_id": group_id}

@app.get("/group/{group_id}/users")
async def get_group_users(group_id: str):
    users = group_manager.get_users_in_group(group_id)
    return {"group_id": group_id, "user_count": len(users), "users": users}
