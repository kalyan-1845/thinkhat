import asyncio
import os
import httpx
import logging
from typing import Optional

logger = logging.getLogger(__name__)

# Mocked or real providers based on presence of API keys
GROQ_API_KEY = os.getenv("GROQ_API_KEY")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")

class AIRouter:
    def __init__(self):
        self.fast_ai_timeout = 3.0
        self.smart_ai_timeout = 8.0

    async def call_fast_ai(self, query: str) -> Optional[str]:
        """Call a Fast AI like Groq, suited for simple tasks."""
        if not GROQ_API_KEY:
            # Mock
            await asyncio.sleep(1)
            return f"[Fast mock response] I am a quick AI processing: '{query}'"

        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    "https://api.groq.com/openai/v1/chat/completions",
                    headers={"Authorization": f"Bearer {GROQ_API_KEY}", "Content-Type": "application/json"},
                    json={
                        "model": "mixtral-8x7b-32768", # Valid groq model example
                        "messages": [{"role": "user", "content": query}]
                    },
                    timeout=self.fast_ai_timeout
                )
                response.raise_for_status()
                data = response.json()
                return data["choices"][0]["message"]["content"]
        except Exception as e:
            logger.error(f"Fast AI Error: {e}")
            return None

    async def call_smart_ai(self, query: str) -> Optional[str]:
        """Call a Smart AI like OpenAI, suited for complex tasks."""
        if not OPENAI_API_KEY:
            # Mock
            await asyncio.sleep(2)
            return f"[Smart mock response] Analyzing the deep complexities of your prompt: '{query}'. It seems quite intricate."

        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    "https://api.openai.com/v1/chat/completions",
                    headers={"Authorization": f"Bearer {OPENAI_API_KEY}", "Content-Type": "application/json"},
                    json={
                        "model": "gpt-4-turbo-preview",
                        "messages": [{"role": "user", "content": query}]
                    },
                    timeout=self.smart_ai_timeout
                )
                response.raise_for_status()
                data = response.json()
                return data["choices"][0]["message"]["content"]
        except Exception as e:
            logger.error(f"Smart AI Error: {e}")
            return None

    async def process_query(self, query: str) -> str:
        """Route the query to the best provider based on query length/complexity and implement fallbacks."""
        # Simple routing logic
        is_complex = len(query) > 100

        try:
            if is_complex:
                logger.info("Routing to Smart AI...")
                reply = await self.call_smart_ai(query)
                if not reply:
                    logger.warning("Smart AI failed, falling back to Fast AI...")
                    reply = await self.call_fast_ai(query)
            else:
                logger.info("Routing to Fast AI...")
                reply = await self.call_fast_ai(query)
                if not reply:
                    logger.warning("Fast AI failed, falling back to Smart AI...")
                    reply = await self.call_smart_ai(query)

            if not reply:
                # Ultimate fallback
                return "AI Services are currently unreachable. Please try again later."
                
            return reply

        except Exception as e:
            logger.error(f"AI Routing Catastrophic Failure: {e}")
            return "An internal error occurred while processing your AI request."

ai_router = AIRouter()
