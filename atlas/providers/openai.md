# OpenAI Provider

- Endpoint: `https://api.openai.com/v1/chat/completions` (customizable for Azure/local)
- Reasoning models (o1, o3, gpt-5): use `max_completion_tokens`, may omit system messages, include `reasoning_effort`
- Images (#231): the openai wire maps an internal image block to a Chat Completions part `{type="image_url", image_url={url="data:<mime>;base64,…", detail="auto"}}`; text-only messages stay plain strings.
