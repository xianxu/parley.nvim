# Spec: Google AI Provider

## Overview
Google AI's provider for Gemini Pro and Gemini Flash.

## Endpoint
- Default: `https://generativelanguage.googleapis.com/v1beta/models/{{model}}:streamGenerateContent?key={{secret}}`.
- Model and secret are embedded in the URL and MUST NOT be in headers or body.

## Payload Structure
- `contents`: List of messages with `role` and `parts[].text`.
- `generationConfig`: `{temperature, maxOutputTokens, topP, topK}`.
- `safetySettings`: Harm categories set to `BLOCK_NONE`.

### Role Mapping
- `system` → `user`.
- `assistant` → `model`.
- Consecutive messages with same role MUST be merged.

## Content Extraction
- Extracts from `candidates[0].content.parts[0].text`.
- Metrics: `promptTokenCount`, `candidatesTokenCount`.
