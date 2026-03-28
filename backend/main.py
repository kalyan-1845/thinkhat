from fastapi import FastAPI, HTTPException, Depends
from typing import Optional
from fastapi.middleware.cors import CORSMiddleware
from websocket import router as websocket_router
from group_manager import group_manager
from database import db
from auth import auth_handler
from utils import generate_group_id, is_valid_username
from models import RoomRequest, LoginRequest, Token
import logging
import asyncio

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="FlowConnect Powered Backend", version="2.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(websocket_router)

@app.on_event("startup")
async def startup_event():
    await db.connect_to_mongo()
    logger.info("MongoDB Initialized")

@app.on_event("shutdown")
async def shutdown_event():
    await db.close_mongo_connection()

@app.get("/")
async def root():
    return {"message": "FlowConnect API with MongoDB Persistence"}

@app.get("/health")
async def health_check():
    return {"status": "ok", "db": "connected"}

@app.post("/auth/login", response_model=Token)
async def login(request: LoginRequest):
    """Simple login that returns a JWT for a username."""
    if not is_valid_username(request.username):
        raise HTTPException(status_code=400, detail="Invalid username format")
    
    access_token = auth_handler.create_access_token(data={"sub": request.username})
    return {"access_token": access_token, "token_type": "bearer"}

@app.post("/group/generate")
async def prepare_group(request: RoomRequest, current_user: dict = Depends(auth_handler.get_current_user)):
    """
    Protected endpoint to generate/verify group membership.
    Must provide Bearer Token in header.
    """
    pattern = request.pattern
    username = current_user["sub"] # Use username from token
    mode = request.mode
    
    if not pattern:
        raise HTTPException(status_code=400, detail="Pattern cannot be empty.")
    
    group_id = generate_group_id(pattern)
    
    if mode == "create":
        await group_manager.create_group(group_id, username)
    else:
        if not await group_manager.group_exists(group_id):
            raise HTTPException(status_code=404, detail="Room not found.")

    return {
        "pattern": pattern, 
        "group_id": group_id, 
        "is_creator": mode == "create"
    }

@app.post("/group/{group_id}/destroy")
async def destroy_room(group_id: str, current_user: dict = Depends(auth_handler.get_current_user)):
    """Wipe the room from DB and memory. Restricted to original creator."""
    username = current_user["sub"]
    
    room = await db.get_room(group_id)
    if not room or room.get("creator") != username:
        raise HTTPException(status_code=403, detail="Only the creator can destroy the room.")
    
    await group_manager.destroy_group(group_id)
    return {"message": "Room destroyed successfully from persistence"}

@app.post("/config")
async def update_config(groq_key: Optional[str] = None):
    import os
    if groq_key:
        os.environ["GROQ_API_KEY"] = groq_key
    return {"message": "Config updated"}

@app.get("/group/{group_id}/users")
async def get_group_users(group_id: str):
    users = group_manager.get_users_in_group(group_id)
    return {"group_id": group_id, "user_count": len(users), "users": users}
