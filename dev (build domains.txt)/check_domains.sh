#!/bin/bash
# Reads a domain list, takes N domains at a time, checks all N at once
# (background jobs), waits for the group to finish, then takes the next N.
# Failed domains (no IPv4 answer, or 0.0.0.0) are appended to failed.txt.
#
# Usage: ./check_domains.sh [N] [domains_file]
#        ./check_domains.sh 100                 (100 at once, domains.txt)
#        ./check_domains.sh 50 mylist.txt
#        SKIP=500000 ./check_domains.sh         (resume: skip first 500000 lines)
#        RESOLVER=1.1.1.1 ./check_domains.sh 100   (ask a specific DNS server)

N="${1:-50}"
FILE="${2:-domains.txt}"
FAILED="${FAILED:-failed.txt}"
SKIP="${SKIP:-0}"

[ -f "$FILE" ] || { echo "$FILE not found - run ./get_domains.sh first"; exit 1; }

TOTAL=$(wc -l < "$FILE" | tr -d ' ')
[ "$SKIP" -eq 0 ] && : > "$FAILED"
trap 'echo; echo "Stopped. Failed so far: $(wc -l < "$FAILED" | tr -d " ") -> $FAILED (resume with SKIP=$DONE)"; kill $(jobs -p) 2>/dev/null; exit 130' INT TERM

check() {
    ip=$(dig ${RESOLVER:+@"$RESOLVER"} +short +time=2 +tries=1 "$1" A < /dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n1)
    if [ -z "$ip" ] || [ "$ip" = "0.0.0.0" ]; then
        echo "$1" >> "$FAILED"
    fi
}

echo "Checking $((TOTAL - SKIP)) domains, $N at a time..."
START=$(date +%s)
DONE=$SKIP
IN_GROUP=0

while read -r domain; do
    check "$domain" &
    IN_GROUP=$((IN_GROUP + 1))
    if [ "$IN_GROUP" -ge "$N" ]; then
        wait
        DONE=$((DONE + IN_GROUP)); IN_GROUP=0
        EL=$(( $(date +%s) - START )); [ "$EL" -lt 1 ] && EL=1
        RATE=$(( (DONE - SKIP) / EL ))
        if [ "$RATE" -gt 0 ]; then ETA=$(( (TOTAL - DONE) / RATE / 60 )); else ETA="?"; fi
        printf '\r[%3d%%] %d / %d | %d failed | %d/sec | ~%s min left   ' \
            $((DONE * 100 / TOTAL)) "$DONE" "$TOTAL" "$(wc -l < "$FAILED" | tr -d ' ')" "$RATE" "$ETA"
    fi
done < <(tail -n +$((SKIP + 1)) "$FILE")
wait

echo
echo "Done. $(wc -l < "$FAILED" | tr -d ' ') failed -> $FAILED"