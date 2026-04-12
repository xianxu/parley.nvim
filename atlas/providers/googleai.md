# Google AI Provider

- Endpoint: model + secret embedded in URL (not headers/body)
- Role mapping: `system` -> `user`, `assistant` -> `model`; consecutive same-role messages must be merged
