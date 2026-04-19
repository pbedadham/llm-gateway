import os

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import openai

app = FastAPI(title="llm-gateway")
DEFAULT_MODEL = os.getenv("OPENAI_MODEL", "gpt-4.1")

class Query(BaseModel):
    prompt: str

@app.post("/ask")
async def ask_llm(query: Query):
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise HTTPException(status_code=500, detail="OPENAI_API_KEY is not set")

    client = openai.AsyncOpenAI(api_key=api_key)

    try:
        response = await client.responses.create(
            model=DEFAULT_MODEL,
            input=query.prompt,
        )
    except openai.OpenAIError as exc:
        raise HTTPException(status_code=502, detail=f"OpenAI request failed: {exc}") from exc

    if not response.output_text:
        raise HTTPException(status_code=502, detail="OpenAI returned no text output")

    return {"answer": response.output_text}

@app.get("/healthz")
def health():
    return {"status": "healthy"}
