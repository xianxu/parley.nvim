# TODO

# ✅ make iterating on parley easier by allowing raw request and response, still within the context of a markdown file

This feature has been implemented:

1. Raw response mode (`raw_mode.show_raw_response: true`) - Displays full JSON responses from LLMs as code blocks
2. Raw request mode (`raw_mode.parse_raw_request: true`) - Allows sending custom JSON requests directly to the API

These modes make it easier to iterate on parley by enabling direct debugging of requests and responses. For example, when using tool-use capable models, you can see the exact format of tool use instructions and implement support for them in the future.

# improve coding ability

Have some [thoughts](https://xianxu.github.io/assets/static/2025-05-24.23-26-50.921.html), which is also in

@@~/chats/2025-05-24.23-26-50.921.md: AI coding with full transcript

