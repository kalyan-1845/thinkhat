import os
import httpx
import logging

logger = logging.getLogger(__name__)

# Replace with your actual API key
GROQ_API_KEY = os.getenv("GROQ_API_KEY", "your_api_key_here")

class AIRouter:
    async def getAIResponse(self, text: str) -> str:
        """Call a real AI API (Groq) and return response text."""
        # Dynamically fetch key from environment in case it was updated by /config
        apiKey = os.getenv("GROQ_API_KEY", "your_api_key_here")
        
        if apiKey == "your_api_key_here":
            return "Please set your GROQ_API_KEY environment variable or in settings to use real AI."
            
        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    "https://api.groq.com/openai/v1/chat/completions",
                    headers={
                        "Authorization": f"Bearer {apiKey}", 
                        "Content-Type": "application/json"
                    },
                    json={
                        "model": "mixtral-8x7b-32768",
                        "messages": [{"role": "user", "content": text}]
                    },
                    timeout=10.0
                )
                response.raise_for_status()
                data = response.json()
                return data["choices"][0]["message"]["content"]
                
        except Exception as e:
            logger.error(f"AI API Failed: {e}")
            return "AI failed, try again"

    async def process_query(self, query: str) -> str:
        """Helper method mapped to the Websocket caller."""
        return await self.getAIResponse(query)

ai_router = AIRouter()
