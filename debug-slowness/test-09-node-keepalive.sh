#!/bin/bash
# Test 9: Node.js HTTP client with connection reuse + idle time
# This simulates what Claude Code / Codex actually do:
# - Open HTTPS connection through proxy
# - Make a request
# - Hold the connection idle
# - Make another request on the same connection
#
# If the proxy breaks idle connections, the 2nd request will hang.
set -euo pipefail

echo "=== Test 09: Node.js keepalive + idle through proxy ==="

node -e '
const https = require("https");

function makeRequest(label) {
    return new Promise((resolve, reject) => {
        const start = Date.now();
        const req = https.request("https://api.anthropic.com/", {timeout: 30000}, (res) => {
            let data = "";
            res.on("data", (chunk) => { data += chunk; });
            res.on("end", () => {
                console.log(label + ": " + res.statusCode + " in " + (Date.now()-start) + "ms");
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
        req.end();
    });
}

async function main() {
    // Rapid requests (connection pooled by Node)
    console.log("--- Rapid requests ---");
    await makeRequest("req1");
    await makeRequest("req2");
    await makeRequest("req3");

    // Idle then reuse
    for (const wait of [30, 60, 120]) {
        console.log("--- Sleeping " + wait + "s ---");
        await new Promise(r => setTimeout(r, wait * 1000));
        await makeRequest("after-" + wait + "s");
    }
}
main();
'
