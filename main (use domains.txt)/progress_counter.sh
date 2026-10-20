#!/bin/bash
# Live stats for a DNS check log (lines like "example.com PASSED 1.2.3.4" or
# "example.com FAILED REFUSED"; a "# started ..." header line is ignored).
#
# Usage: ./watch_progress.sh [logfile]      (Ctrl-C to quit)

LOG="${1:-$(cat "$(dirname "$0")/current_log.txt")}"

[ -f "$LOG" ] || { echo "Log file not found: $LOG"; exit 1; }

while true; do
    # One pass over the log: total records, FAILED records, FAILED REFUSED records.
    read -r total failed found_targets <<< "$(awk '
        /^#/ { next }
        { t++ }
        $2 == "FAILED" { f++; if ($3 == "REFUSED") r++ }
        END { print t + 0, f + 0, r + 0 }' "$LOG")"

    passed=$((total - failed))
    rate=$(awk -v p="$passed" -v t="$total" 'BEGIN { printf "%.2f", (t > 0 ? p / t * 100 : 0) }')

    clear
    printf '\n LOG: %s\n' "$LOG"
    printf '\n DNS PASSED: %s\n' "$passed"
    printf ' DNS FAILED: %s\n' "$failed"
    printf ' TOTAL RECORDS: %s - pass rate: %s%%\n' "$total" "$rate"
    printf '\n TARGETS FOUND: %s\n' "$found_targets"

    sleep 1
done