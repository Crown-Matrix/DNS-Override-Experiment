#!/bin/bash
# Checks the domains in domains.txt (no downloading). Logs every result to
# the log file AS IT HAPPENS, one line per domain:
#
#   example.com PASSED 93.184.216.34
#   blocked.com FAILED sinkhole        (resolver returned 0.0.0.0 or 127.0.0.1)
#   dead.com    FAILED NXDOMAIN        (domain does not exist)
#   refused.com FAILED REFUSED         (resolver declined to answer)
#   broken.com  FAILED SERVFAIL        (resolver error)
#   slow.com    FAILED timeout         (no reply in time)
#   noa.com     FAILED -a-record     (domain exists, no IPv4 address)
#   odd.com     FAILED other-<STATUS>  (any other DNS status)
#   x.com       FAILED dig-error       (dig gave no usable output; is dig installed?)
#
# W workers run at once; each streams through its own share of the list, so one
# slow lookup never holds the others up. The list is shuffled first so the load
# is even and the % / ETA is representative.
#
# Usage: ./check_verbose.sh [WORKERS] [domains_file]
#        ./check_verbose.sh 60                  (default 60, max 600)
#        TIMEOUT=1 ./check_verbose.sh 60        (1s DNS timeout)
#        RESOLVER=1.1.1.1 ./check_verbose.sh 60
#        LOG=other.txt ./check_verbose.sh 60
#
# RESUME: domains already in the log are skipped. To start over: rm the log
#         (or RESUME=0). Watch live from a second tab using progress_counter.sh


CONFIGURED_LOG_NAME="current_log.txt"
if [[ $(wc -l < "$FILE") -ne 1 || ! -s "$FILE" || ! -n "$(cat "$FILE")" ]]; then
    echo "invalid current_log.txt"
    exit 1
fi

export LC_ALL=C
W="${1:-60}"
FILE="${2:-domains.txt}"
LOG="${LOG:-$(cat "$(dirname "$0")/current_log.txt")}"
TIMEOUT="${TIMEOUT:-2}"
RESUME="${RESUME:-1}"
[ "$W" -gt 600 ] && W=600

[ -f "$FILE" ] || { echo "$FILE not found"; exit 1; }
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# ---- work out what's left to do ----
sort -u "$FILE" > "$WORK/all.txt"
TOTAL=$(wc -l < "$WORK/all.txt" | tr -d ' ')
if [ "$RESUME" = "1" ] && [ -s "$LOG" ]; then
    grep -v '^#' "$LOG" | cut -d' ' -f1 | sort -u > "$WORK/done.txt"
    comm -23 "$WORK/all.txt" "$WORK/done.txt" > "$WORK/todo.txt"
    echo "Resuming: $(wc -l < "$WORK/done.txt" | tr -d ' ') already in $LOG"
else
    cp "$WORK/all.txt" "$WORK/todo.txt"
    echo "# started $(date)" > "$LOG"
fi
TODO=$(wc -l < "$WORK/todo.txt" | tr -d ' ')
[ "$TODO" -gt 0 ] || { echo "Nothing left to check."; exit 0; }
ALREADY=$((TOTAL - TODO))

# shuffle, then give each worker its own chunk
sort -R "$WORK/todo.txt" > "$WORK/shuf.txt"
split -l $(( (TODO + W - 1) / W )) "$WORK/shuf.txt" "$WORK/chunk_"

# ---- worker: one chunk, one domain at a time ----
worker() {
    set -f
    while read -r d; do
        out=$(dig ${RESOLVER:+@"$RESOLVER"} +noall +answer +comments +time="$TIMEOUT" +tries=1 "$d" A < /dev/null 2>&1)
        # first IPv4 A record in the answer section (skips CNAME lines)
        ip=$(awk '$4=="A"{print $5; exit}' <<< "$out")
        # DNS status from the header (NOERROR, NXDOMAIN, REFUSED, SERVFAIL, ...)
        st=$(sed -n 's/.*status: \([A-Z]*\).*/\1/p' <<< "$out" | head -1)

        if [ -n "$ip" ]; then
            if [ "$ip" = "0.0.0.0" ] || [ "$ip" = "127.0.0.1" ]; then
                echo "$d FAILED sinkhole" >> "$LOG"
            else
                echo "$d PASSED $ip" >> "$LOG"
            fi
        else
            case "$st" in
                NXDOMAIN) echo "$d FAILED NXDOMAIN" >> "$LOG" ;;
                REFUSED)  echo "$d FAILED REFUSED" >> "$LOG" ;;
                SERVFAIL) echo "$d FAILED SERVFAIL" >> "$LOG" ;;
                NOERROR)  echo "$d FAILED no-a-record" >> "$LOG" ;;
                "")
                    if grep -qE 'timed out|no servers could be reached' <<< "$out"; then
                        echo "$d FAILED timeout" >> "$LOG"
                    else
                        echo "$d FAILED dig-error" >> "$LOG"
                    fi ;;
                *) echo "$d FAILED other-$st" >> "$LOG" ;;
            esac
        fi
    done < "$1"
}

trap 'echo; echo "Stopped. Results so far are in $LOG. Rerun the same command to resume."; kill $(jobs -p) 2>/dev/null; rm -rf "$WORK"; exit 130' INT TERM

echo "Checking $TODO domains with $W workers (timeout ${TIMEOUT}s). Log: $LOG  (watch: tail -f $LOG)"
BASE=$(wc -l < "$LOG" | tr -d ' ')
for chunk in "$WORK"/chunk_*; do
    worker "$chunk" &
done

# ---- progress display ----
START=$(date +%s)
while [ "$(jobs -r | wc -l | tr -d ' ')" -gt 0 ]; do
    sleep 2
    NOW_LINES=$(wc -l < "$LOG" | tr -d ' ')
    DONE=$((NOW_LINES - BASE))
    EL=$(( $(date +%s) - START )); [ "$EL" -lt 1 ] && EL=1
    RATE=$((DONE / EL))
    if [ "$RATE" -gt 0 ]; then ETA=$(( (TODO - DONE) / RATE / 60 )); else ETA="?"; fi
    printf '\r[%3d%%] %d / %d | %d/sec | ~%s min left   ' \
        $(( (ALREADY + DONE) * 100 / TOTAL )) $((ALREADY + DONE)) "$TOTAL" "$RATE" "$ETA"
done
wait
echo
echo "Finished in $(( $(date +%s) - START ))s. PASSED: $(grep -c ' PASSED ' "$LOG")  FAILED: $(grep -c ' FAILED ' "$LOG")  (log: $LOG)"
echo "Breakdown of failures:"
grep ' FAILED ' "$LOG" | cut -d' ' -f3 | sort | uniq -c | sort -rn