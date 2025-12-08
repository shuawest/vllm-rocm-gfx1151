import asyncio
import httpx
import uvicorn
from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import StreamingResponse, JSONResponse
from contextlib import asynccontextmanager
import logging

# Configuration
START_PORT = 8081
END_PORT = 8099
HOST = "0.0.0.0"
PORT = 8000

# Logging Setup
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("ai-router")

# Global State
# Mapping: model_id -> port
model_registry = {}

async def scan_services():
    """Scans ports to find running llama.cpp instances."""
    global model_registry
    logger.info("🔍 Scanning for AI services...")
    
    new_registry = {}
    async with httpx.AsyncClient(timeout=2.0) as client:
        tasks = []
        for port in range(START_PORT, END_PORT + 1):
            tasks.append(check_port(client, port))
        
        results = await asyncio.gather(*tasks)
        
        for port, models in results:
            if models:
                for model in models:
                    model_id = model['id']
                    new_registry[model_id] = port
                    logger.info(f"✅ Found {model_id} on port {port}")
    
    model_registry = new_registry
    logger.info(f"🏁 Scan complete. Registered {len(model_registry)} models.")

async def check_port(client, port):
    """Checks a single port for /v1/models."""
    try:
        url = f"http://localhost:{port}/v1/models"
        response = await client.get(url)
        if response.status_code == 200:
            data = response.json()
            return port, data.get('data', [])
    except Exception:
        pass
    return port, []

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifecycle manager: Scan on startup and periodically."""
    # Initial scan
    await scan_services()
    
    # Background task for periodic scanning (every 60s)
    asyncio.create_task(periodic_scan())
    yield

async def periodic_scan():
    while True:
        await asyncio.sleep(60)
        await scan_services()

app = FastAPI(lifespan=lifespan)

@app.get("/v1/models")
async def list_models():
    """Aggregates models from all discovered services."""
    # Re-scan on demand (optional, but good for debugging)
    # await scan_services()
    
    combined_data = []
    for model_id, port in model_registry.items():
        combined_data.append({
            "id": model_id,
            "object": "model",
            "owned_by": "system",
            "permission": []
        })
    
    return {"object": "list", "data": combined_data}

@app.post("/v1/chat/completions")
async def chat_completions(request: Request):
    """Proxies chat completion requests to the correct backend."""
    try:
        body = await request.json()
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid JSON body")

    model_id = body.get("model")
    if not model_id:
        raise HTTPException(status_code=400, detail="Missing 'model' field")

    target_port = model_registry.get(model_id)
    
    # Fallback: If model not found, try to match partial name or default
    if not target_port:
        # Try to find a partial match
        for reg_id, port in model_registry.items():
            if model_id in reg_id or reg_id in model_id:
                target_port = port
                logger.info(f"⚠️ Fuzzy match: {model_id} -> {reg_id} on port {port}")
                break
    
    if not target_port:
        # Trigger a re-scan just in case it just started
        await scan_services()
        target_port = model_registry.get(model_id)
        
    if not target_port:
        raise HTTPException(status_code=404, detail=f"Model '{model_id}' not found. Available: {list(model_registry.keys())}")

    target_url = f"http://localhost:{target_port}/v1/chat/completions"
    logger.info(f"➡️ Proxying request for {model_id} to {target_url}")

    # Create a client for the proxy request
    client = httpx.AsyncClient(timeout=None) # No timeout for streaming
    
    req = client.build_request(
        request.method,
        target_url,
        headers=request.headers,
        content=request.stream(),
    )
    
    r = await client.send(req, stream=True)
    
    return StreamingResponse(
        r.aiter_raw(),
        status_code=r.status_code,
        headers=r.headers,
        background=None
    )

if __name__ == "__main__":
    uvicorn.run(app, host=HOST, port=PORT)
