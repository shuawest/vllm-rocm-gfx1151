
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "any",
    "messages": [{"role": "user", "content": "Say hi from gfx1151 ROCm"}],
    "max_tokens": 64
  }'
  