# Google AI Provider

- Endpoint: model + secret embedded in URL (not headers/body)
- Role mapping: `system` -> `user`, `assistant` -> `model`; consecutive same-role messages must be merged
- Images (#231): `format_payload` maps an internal image block to `{inlineData={mimeType, data}}` (camelCase) and the same-role merge appends whole `parts` lists; 20 MB inline request cap.
