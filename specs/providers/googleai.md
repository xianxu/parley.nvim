# Google AI Provider

- Endpoint: `https://generativelanguage.googleapis.com/v1beta/models/{{model}}:streamGenerateContent?key={{secret}}` (model+secret in URL, NOT in headers/body)
- Payload: `contents` (list of `{role, parts[].text}`), `generationConfig` (`temperature`, `maxOutputTokens`, `topP`, `topK`), `safetySettings` (all `BLOCK_NONE`)
- Role mapping: `system` -> `user`, `assistant` -> `model`; consecutive same-role messages MUST be merged
- Content extraction: `candidates[0].content.parts[0].text`
- Usage: `promptTokenCount`, `candidatesTokenCount`
