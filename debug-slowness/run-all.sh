#!/bin/bash
# Run all tests and collect results
# Usage: bash debug-slowness/run-all.sh
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
LOG="$DIR/results-$(date +%Y%m%d-%H%M%S).txt"

echo "Results will be saved to: $LOG"
echo "Started at: $(date)" | tee "$LOG"
echo "" | tee -a "$LOG"

for test in "$DIR"/test-*.sh; do
    echo "---" | tee -a "$LOG"
    echo "Running: $(basename "$test")" | tee -a "$LOG"
    bash "$test" 2>&1 | tee -a "$LOG"
    echo "" | tee -a "$LOG"
done

echo "---" | tee -a "$LOG"
echo "Finished at: $(date)" | tee -a "$LOG"
echo "Results saved to: $LOG"
