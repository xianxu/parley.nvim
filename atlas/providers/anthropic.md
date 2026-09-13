# Anthropic Provider

- Endpoint: `https://api.anthropic.com/v1/messages`
- Web search tools available when enabled; Haiku models need `allowed_callers: ["direct"]`
- Images (#231): user content block `{type="image", source={type="base64", media_type, data}}`, images before text; 10 MB per image, 100 per request, 32 MB per request.
