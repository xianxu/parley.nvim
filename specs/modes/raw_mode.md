# Spec: Raw Mode

## Overview
Raw mode provides developers with direct access to API payloads and responses.

## Configuration
- `raw_mode.enable`: Boolean to enable/disable.
- `raw_mode.show_raw_response`: Toggles display of raw JSON API responses.
- `raw_mode.parse_raw_request`: Toggles parsing of user JSON as requests.

## Raw Response Mode
- When active, the plugin MUST NOT extract content from the API stream.
- Instead, it MUST wrap the entire JSON response in a ` ```json ` code block.

## Raw Request Mode
- The plugin MUST look for a fenced JSON code block in the current question.
- If found, that JSON is sent directly as the API request body, bypassing normal payload construction.

## Commands
- `:ParleyToggleRaw`: Toggles both modes.
- `:ParleyToggleRawRequest` (`<C-g>r`): Toggles raw request parsing.
- `:ParleyToggleRawResponse` (`<C-g>R`): Toggles raw response display.
