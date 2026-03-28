import os
import httpx
import logging
import asyncio
from dotenv import load_dotenv

load_dotenv()
logger = logging.getLogger(__name__)

# --- Provider Configurations ---
PROVIDERS = {
    "groq": {
        "base_url": "https://api.groq.com/openai/v1/chat/completions",
        "api_key_env": "GROQ_API_KEY",
        "model": "llama-3.3-70b-versatile"
    },
    "siliconflow": {
        "base_url": "https://api.siliconflow.cn/v1/chat/completions",
        "api_key_env": "SILICONFLOW_API_KEY",
        "model": "Qwen/Qwen2.5-72B-Instruct"
    },
    "openai": {
        "base_url": "https://api.openai.com/v1/chat/completions",
        "api_key_env": "OPENAI_API_KEY",
        "model": "gpt-4o-mini"
    },
    "gemini": {
        "base_url": "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions",
        "api_key_env": "GEMINI_API_KEY",
        "model": "gemini-2.0-flash"
    }
}

class AIRouter:
    async def _call_api(self, provider_id: str, text: str, client: httpx.AsyncClient) -> str:
        """Isolated API call to a specific provider."""
        config = PROVIDERS[provider_id]
        api_key = os.getenv(config["api_key_env"])
        
        # Simple validation before calling
        if not api_key or "your_" in api_key or api_key == "":
             raise ValueError(f"No key for {provider_id}")

        response = await client.post(
            config["base_url"],
            headers={
                "Authorization": f"Bearer {api_key}", 
                "Content-Type": "application/json"
            },
            json={
                "model": config["model"],
                "messages": [
                    {
                        "role": "system", 
                        "content": "You are a collaborative AI for FlowConnect. Give a single, concise, and direct reply to help grow the user's idea."
                    },
                    {"role": "user", "content": text}
                ]
            },
            timeout=15.0
        )
        
        if response.status_code != 200:
             raise RuntimeError(f"{provider_id} error {response.status_code}")

        data = response.json()
        return data["choices"][0]["message"]["content"]

    async def getAIResponse(self, text: str) -> str:
        """Race multiple providers to get the fastest response."""
        is_race_mode = os.getenv("AI_RACE_MODE", "False").lower() == "true"
        active_choice = os.getenv("ACTIVE_AI_PROVIDER", "groq").lower()
        
        # 1. Identify valid providers (those with keys)
        valid_providers = []
        for pid in PROVIDERS:
            key = os.getenv(PROVIDERS[pid]["api_key_env"])
            if key and "your_" not in key and key != "":
                valid_providers.append(pid)

        if not valid_providers:
            return "Error: No valid AI API keys found in `.env`. Please add at least one key."

        # 2. Execute logic based on mode
        async with httpx.AsyncClient() as client:
            if not is_race_mode:
                # Single provider mode (Active one or first valid)
                target = active_choice if active_choice in valid_providers else valid_providers[0]
                try:
                    return await self._call_api(target, text, client)
                except Exception as e:
                    return f"AI Error from {target}: {e}"
            
            # RACE MODE
            logger.info(f"🏎️  Starting AI Race with providers: {valid_providers}")
            tasks = [asyncio.create_task(self._call_api(pid, text, client), name=pid) for pid in valid_providers]
            
            done, pending = await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED)
            
            # Identify the winner
            winner_task = done.pop()
            winner_name = winner_task.get_name()
            
            # Cleanup: Cancel all other tasks instantly
            for task in pending:
                task.cancel()
            
            try:
                result = await winner_task
                logger.info(f"🏆 AI Race Winner: {winner_name}")
                return result
            except Exception as e:
                # If the winner failed, we might need to check other finished ones or retry
                logger.error(f"Race winner {winner_name} failed: {e}. Trying fallback...")
                if done: # If another finished at the same time and succeeded
                     try: return await done.pop()
                     except: pass
                # Default fallback - try the first pending if any (though usually we'd want a more robust retry)
                return "AI Race failed. Please check your provider keys and internet."

    async def process_query(self, query: str) -> str:
        """Helper method mapped to the Websocket caller."""
        return await self.getAIResponse(query)

ai_router = AIRouter()
