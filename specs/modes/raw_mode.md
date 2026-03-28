# Raw Mode

- `raw_mode.enable`, `raw_mode.show_raw_response`, `raw_mode.parse_raw_request`
- **Raw response**: entire JSON response wrapped in ```json block, no content extraction
- **Raw request**: fenced JSON block in question sent as-is as API request body, bypassing normal payload construction
- `:ParleyToggleRaw`: toggle both
- `:ParleyToggleRawRequest` (`<C-g>r`): toggle request parsing
- `:ParleyToggleRawResponse` (`<C-g>R`): toggle response display
