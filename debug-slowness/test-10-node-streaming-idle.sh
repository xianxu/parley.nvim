#!/bin/bash
# Test 10: Node.js SSE-like streaming + idle + reuse
# Closest simulation of what Claude Code does:
# 1. POST a streaming request, read the full SSE response
# 2. Idle for N seconds (simulating user think time / tool execution)
# 3. POST another streaming request on the reused connection
#
# If the proxy breaks streaming connections after idle, step 3 hangs.
set -euo pipefail

echo "=== Test 10: Node.js streaming + idle + reuse ==="

node -e '
const https = require("https");

function streamRequest(label) {
    return new Promise((resolve) => {
        const start = Date.now();
        const postData = JSON.stringify({
            model: "claude-sonnet-4-20250514",
            max_tokens: 5,
            stream: true,
            messages: [{role: "user", content: "hi"}]
        });

        const options = {
            hostname: "api.anthropic.com",
            path: "/v1/messages",
            method: "POST",
            headers: {
                "content-type": "application/json",
                "anthropic-version": "2023-06-01",
                "x-api-key": "sk-fake-key-for-testing",
                "content-length": Buffer.byteLength(postData)
            },
            timeout: 30000
        };

        const req = https.request(options, (res) => {
            let bytes = 0;
            let firstByte = 0;
            res.on("data", (chunk) => {
                if (!firstByte) firstByte = Date.now() - start;
                bytes += chunk.length;
            });
            res.on("end", () => {
                const total = Date.now() - start;
                console.log(label + ": HTTP " + res.statusCode + " ttfb=" + firstByte + "ms total=" + total + "ms bytes=" + bytes);
                resolve();
            });
        });
        req.on("error", (e) => {
            console.log(label + ": ERROR " + e.message + " in " + (Date.now()-start) + "ms");
            resolve();
        });
        req.on("timeout", () => {
            console.log(label + ": TIMEOUT in " + (Date.now()-start) + "ms");
            req.destroy();
            resolve();
        });
        req.write(postData);
        req.end();
    });
}

async function main() {
    console.log("--- Rapid streaming requests ---");
    await streamRequest("stream1");
    await streamRequest("stream2");

    for (const wait of [30, 60, 120]) {
        console.log("--- Sleeping " + wait + "s ---");
        await new Promise(r => setTimeout(r, wait * 1000));
        await streamRequest("after-" + wait + "s");
    }
}
main();
'
