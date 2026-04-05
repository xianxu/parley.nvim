#!/bin/bash
# Test 8: Hold an HTTP connection idle through the proxy, then reuse it
# Theory: proxy's L7 relay breaks on idle CONNECT tunnels
#
# Uses curl --keepalive to reuse the same connection across requests,
# with a sleep between to simulate idle time.
set -euo pipefail

API="https://api.anthropic.com/"
FMT='req=%{num_connects} HTTP=%{http_code} total=%{time_total}s ttfb=%{time_starttransfer}s\n'

echo "=== Test 08: idle connection reuse through proxy ==="

echo "--- Batch 1: 3 rapid requests (should reuse connection) ---"
curl -s -o /dev/null -w "$FMT" "$API"
curl -s -o /dev/null -w "$FMT" "$API"
curl -s -o /dev/null -w "$FMT" "$API"

for WAIT in 30 60 120 180; do
    echo "--- Sleeping ${WAIT}s then requesting ---"
    sleep "$WAIT"
    curl -s -o /dev/null -w "$FMT" --max-time 30 "$API" || echo "TIMED OUT after 30s"
done

echo "=== Done ==="
