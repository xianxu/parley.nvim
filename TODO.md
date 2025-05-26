# TODO

# make iterating on parley easier by allowing raw request and response, still within the context of a markdown file

add two global modes to change how content of markdown file's interpreted. 

1. the first mode would print all response from LLM (typically JSON, if not convert to JSON) as a code block enclosed with ```json ... ```
2. the second mode would interpret user's as a single code block that contains JSON string to be sent to LLM. user will provide the actual content within ```json ...``` structure, parley will strip leading/training whitespaces, and strip the ```json and ```, before sending to LLM.

With those two, it will be much easier to iterator on parley, so that user can directly debug request and response. for example, if there were MCP tool use instruction coming back, we'd notice the format and implement it in the future. 

# improve coding ability

Have some [thoughts](https://xianxu.github.io/assets/static/2025-05-24.23-26-50.921.html).

