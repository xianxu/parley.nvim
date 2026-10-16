"""SSE wire dialects for the provider fakes (#242, ARCH-MOCK).

One implementation per wire, imported by every fake that speaks it
(fake_provider, and fake_cliproxy for its chat surface). Pure: an abstract
reply in, the exact bytes the real API streams out. The event templates are
lifted from the recorded fixtures (tests/fixtures/anthropic_*.txt), so the
shape is real bytes. The replies need not make sense; they must be
structurally faithful and consistent across one interaction's calls.

Abstract reply kinds:
  {"kind": "text", "text": str}
  {"kind": "thinking", "thinking": str, "text": str}   # a thinking block, then text
  {"kind": "tool_use", "id": str, "name": str, "input": dict}
  {"kind": "inband_error", "text": str, "error_type": str, "message": str}
  {"kind": "cap", "text": str}             # the output-token cap
  {"kind": "no_stop", "text": str}         # stream ends with no stop reason

Run directly to emit a reply for a spec:
  python3 -I sse_dialects.py emit <dialect> <kind>
"""
import json
import random
import sys

sys.dont_write_bytecode = True  # never write __pycache__ into the repo (#202)

FIXTURE_TEXT = "Hello, world! 👋"  # anthropic_stream.txt's three text deltas
TEXT_DELTAS = ["Hello,", " world! ", "👋"]


def _event(name, payload):
    # Compact, as the real API sends it.
    return ("event: %s\ndata: %s\n\n" % (name, json.dumps(payload, ensure_ascii=False, separators=(",", ":")))).encode("utf-8")


def _deltas(text):
    """Split text into the fixture's delta sizes when it IS the fixture text."""
    return TEXT_DELTAS if text == FIXTURE_TEXT else [text]


def anthropic(reply):
    out = [_event("message_start", {"type": "message_start", "message": {
        "model": "claude-fake", "id": "msg_fake", "type": "message", "role": "assistant", "content": [],
        "stop_reason": None, "stop_sequence": None, "usage": {"input_tokens": 11, "output_tokens": 2}}})]
    kind = reply["kind"]
    index = 0
    if kind == "thinking":
        # anthropic_thinking_only_max_tokens.txt: thinking deltas, then a signature.
        out.append(_event("content_block_start", {"type": "content_block_start", "index": 0,
                                                  "content_block": {"type": "thinking", "thinking": "", "signature": ""}}))
        out.append(_event("content_block_delta", {"type": "content_block_delta", "index": 0,
                                                  "delta": {"type": "thinking_delta", "thinking": reply["thinking"]}}))
        out.append(_event("content_block_delta", {"type": "content_block_delta", "index": 0,
                                                  "delta": {"type": "signature_delta", "signature": "AAAAfake"}}))
        out.append(_event("content_block_stop", {"type": "content_block_stop", "index": 0}))
        index = 1
    if kind == "tool_use":
        out.append(_event("content_block_start", {"type": "content_block_start", "index": 0, "content_block": {
            "type": "tool_use", "id": reply["id"], "name": reply["name"], "input": {}}}))
        args = json.dumps(reply["input"])
        for part in (args[: len(args) // 2], args[len(args) // 2:]):  # input_json_delta arrives in pieces
            out.append(_event("content_block_delta", {"type": "content_block_delta", "index": 0,
                                                      "delta": {"type": "input_json_delta", "partial_json": part}}))
        out.append(_event("content_block_stop", {"type": "content_block_stop", "index": 0}))
        stop = "tool_use"
    else:
        out.append(_event("content_block_start", {"type": "content_block_start", "index": index,
                                                  "content_block": {"type": "text", "text": ""}}))
        out.append(_event("ping", {"type": "ping"}))
        for d in _deltas(reply.get("text", "")):
            out.append(_event("content_block_delta", {"type": "content_block_delta", "index": index,
                                                      "delta": {"type": "text_delta", "text": d}}))
        if kind == "inband_error":
            # anthropic_inband_error.txt: the error event ends the stream mid-answer.
            out.append(_event("error", {"type": "error", "error": {"type": reply["error_type"],
                                                                   "message": reply["message"]}}))
            return b"".join(out)
        out.append(_event("content_block_stop", {"type": "content_block_stop", "index": index}))
        if kind == "no_stop":
            return b"".join(out)
        stop = "max_tokens" if kind == "cap" else "end_turn"
    out.append(_event("message_delta", {"type": "message_delta",
                                        "delta": {"stop_reason": stop, "stop_sequence": None},
                                        "usage": {"output_tokens": 10}}))
    out.append(_event("message_stop", {"type": "message_stop"}))
    return b"".join(out)


def anthropic_error_body(status):
    """The JSON body the Messages API returns with an HTTP error status."""
    kinds = {429: ("rate_limit_error", "Number of request tokens has exceeded your per-minute rate limit"),
             529: ("overloaded_error", "Overloaded"), 500: ("api_error", "Internal server error"),
             401: ("authentication_error", "invalid x-api-key")}
    error_type, message = kinds.get(status, ("api_error", "fake error %d" % status))
    return json.dumps({"type": "error", "error": {"type": error_type, "message": message}}).encode()


DIALECTS = {"anthropic": anthropic}
ERROR_BODIES = {"anthropic": anthropic_error_body}

TOOL_ID = "toolu_fake_1"
TOOL_INPUT = {"path": "README.md"}


def _has_tool_result(request):
    """anthropic: the last message's content holds a tool_result block."""
    messages = request.get("messages") or []
    if not messages:
        return False
    content = messages[-1].get("content")
    return isinstance(content, list) and any(
        isinstance(b, dict) and b.get("type") == "tool_result" for b in content)


# Every --mode the fake accepts; anything else is refused at startup.
MODES = ("ok", "inband_error", "inband_error_empty", "cap", "cap_empty", "no_stop", "thinking")
SPLITS = ("none", "every_byte", "frames")


def check_mode(mode):
    """The mode, or ValueError: http_<status>[_once] and disconnect_after:<bytes>
    take a number; the rest are MODES."""
    if mode in MODES:
        return mode
    if mode.startswith("http_"):
        status = mode[5:][:-5] if mode.endswith("_once") else mode[5:]
        if status.isdigit() and 400 <= int(status) <= 599:
            return mode
    if mode.startswith("disconnect_after:") and mode.split(":", 1)[1].isdigit():
        return mode
    raise ValueError("unknown mode: " + mode)


def check_split(mode):
    if mode in SPLITS or (mode.startswith("random:") and mode.split(":", 1)[1].isdigit()):
        return mode
    raise ValueError("unknown split: " + mode)


def behaviour(request, mode):
    """Request -> abstract reply. Keyed on the REQUEST, never a counter, so it
    stays right under retries and concurrent buffers (as fake_cliproxy's tool
    mode is). `mode` selects the failure shapes a recording cannot show."""
    if mode == "inband_error":
        return {"kind": "inband_error", "text": "Starting the answer and then ",
                "error_type": "overloaded_error", "message": "Overloaded"}
    if mode == "cap":
        return {"kind": "cap", "text": "The answer was cut off at the cap"}
    # The empty-text variants are #228's reported failure: bytes arrived but no
    # answer text, which the pre-fix code called "response is empty".
    if mode == "cap_empty":
        return {"kind": "cap", "text": ""}
    if mode == "inband_error_empty":
        return {"kind": "inband_error", "text": "", "error_type": "overloaded_error", "message": "Overloaded"}
    if mode == "no_stop":
        return {"kind": "no_stop", "text": FIXTURE_TEXT}
    if mode == "thinking":
        return {"kind": "thinking", "thinking": "Let me plan the answer.", "text": FIXTURE_TEXT}
    if _has_tool_result(request):
        return {"kind": "text", "text": "Done: the tool result was received."}
    if request.get("tools"):
        return {"kind": "tool_use", "id": TOOL_ID, "name": "read_file", "input": TOOL_INPUT}
    return {"kind": "text", "text": FIXTURE_TEXT}


def split(body, mode):
    """The write boundaries: the chunking curl hands parley is not the chunking
    the API sent. Concatenating the slices always gives `body` back."""
    if mode in (None, "", "none"):
        return [body]
    if mode == "every_byte":
        return [body[i:i + 1] for i in range(len(body))]
    if mode == "frames":
        # One write per SSE frame (each ends at its blank line).
        frames = [f + b"\n\n" for f in body.split(b"\n\n")]
        frames[-1] = frames[-1][:-2]
        return [f for f in frames if f]
    if mode.startswith("random:"):
        rng = random.Random(int(mode.split(":", 1)[1]))
        out, i = [], 0
        while i < len(body):
            n = rng.randint(8, 64)
            out.append(body[i:i + n])
            i += n
        return out
    raise ValueError("unknown split mode: " + mode)


if __name__ == "__main__":
    if len(sys.argv) >= 4 and sys.argv[1] == "emit":
        dialect, kind = sys.argv[2], sys.argv[3]
        reply = {"text": {"kind": "text", "text": FIXTURE_TEXT},
                 "tool_use": {"kind": "tool_use", "id": TOOL_ID, "name": "read_file", "input": TOOL_INPUT},
                 "inband_error": behaviour({}, "inband_error"), "cap": behaviour({}, "cap"),
                 "no_stop": behaviour({}, "no_stop"), "thinking": behaviour({}, "thinking")}[kind]
        sys.stdout.buffer.write(DIALECTS[dialect](reply))
    else:
        sys.stderr.write("usage: sse_dialects.py emit <dialect> <kind>\n")
        sys.exit(2)
