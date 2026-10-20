#!/bin/bash
# Downloads the Tranco top-1M domains, checks each with dig using parallel
# background jobs, and writes every failed domain to failed_domains.txt.
#
# Usage: ./check_million.sh          (JOBS=100 by default)
#        JOBS=200 ./check_million.sh

JOBS="${JOBS:-100}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# 1. download the list
curl -fsSL https://tranco-list.eu/top-1m.csv.zip -o "$WORK/top.zip" || { echo "download failed"; exit 1; }
unzip -p "$WORK/top.zip" | cut -d, -f2 | tr -d '\r' > "$WORK/tranco.txt"

# add the built-in list (builtin_domains.txt, next to this script)
HERE="$(cd "$(dirname "$0")" && pwd)"
[ -f "$HERE/builtin_domains.txt" ] && cp "$HERE/builtin_domains.txt" "$WORK/builtin.txt" || : > "$WORK/builtin.txt"

# add category blocklists (hosts format) from GitHub
: > "$WORK/blocklists.txt"
BLP=https://raw.githubusercontent.com/blocklistproject/Lists/master
SB=https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates
for url in $BLP/porn.txt $BLP/gambling.txt $BLP/piracy.txt $BLP/torrent.txt $BLP/crypto.txt \
           $BLP/drugs.txt $BLP/facebook.txt $BLP/tiktok.txt $BLP/twitter.txt $BLP/whatsapp.txt \
           $BLP/youtube.txt $SB/porn-only/hosts $SB/gambling-only/hosts $SB/social-only/hosts \
           $SB/fakenews-only/hosts; do
    curl -fsSL "$url" | awk '$1=="0.0.0.0" || $1=="127.0.0.1" {print $2}' >> "$WORK/blocklists.txt"
done
# add plain domain lists from Hagezi
for name in nsfw gambling social anti.piracy doh-vpn-proxy-bypass dyndns; do
    curl -fsSL "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/$name-onlydomains.txt" \
      | grep -v '^#' >> "$WORK/blocklists.txt"
done

# combine, lowercase, keep valid-looking hostnames, de-duplicate
cat "$WORK/tranco.txt" "$WORK/builtin.txt" "$WORK/blocklists.txt" | tr -d '\r' | tr 'A-Z' 'a-z' \
  | grep -E '^([a-z0-9]([a-z0-9_-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$' | sort -u > "$WORK/domains.txt"
TOTAL=$(wc -l < "$WORK/domains.txt" | tr -d ' ')
echo "Checking $TOTAL domains with $JOBS jobs..."

# 2. split into one chunk per job
split -l $(( (TOTAL + JOBS - 1) / JOBS )) "$WORK/domains.txt" "$WORK/chunk_"

# combine all failures into failed_domains.txt (also used if you press Ctrl+C)
finish() {
    cat "$WORK"/chunk_*.failed 2>/dev/null | sort > failed_domains.txt
    echo "$(wc -l < failed_domains.txt | tr -d ' ') failed domains saved -> failed_domains.txt"
}
trap 'echo; echo "Interrupted - saving partial results..."; kill $(jobs -p) 2>/dev/null; finish; exit 130' INT TERM

# 3. one background job per chunk, each loops over its domains
for chunk in "$WORK"/chunk_*; do
    (
        n=0
        while read -r domain; do
            ip=$(dig +short +time=2 +tries=1 "$domain" A | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n1)
            if [ -z "$ip" ] || [ "$ip" = "0.0.0.0" ]; then
                echo "$domain"
            fi
            n=$((n + 1))
            if [ $((n % 25)) -eq 0 ]; then echo "$n" > "$chunk.count"; fi
        done < "$chunk" > "$chunk.failed"
        echo "$n" > "$chunk.count"
    ) &
done

# 4. show progress until every job is done
START=$(date +%s)
while [ "$(jobs -r | wc -l | tr -d ' ')" -gt 0 ]; do
    sleep 2
    DONE=$(cat "$WORK"/chunk_*.count 2>/dev/null | awk '{s+=$1} END{print s+0}')
    FAILED=$(cat "$WORK"/chunk_*.failed 2>/dev/null | wc -l | tr -d ' ')
    NOW=$(date +%s); EL=$((NOW - START)); [ "$EL" -lt 1 ] && EL=1
    RATE=$((DONE / EL))
    if [ "$RATE" -gt 0 ]; then ETA=$(( (TOTAL - DONE) / RATE / 60 )); else ETA="?"; fi
    printf '\r[%3d%%] %d / %d checked | %d failed | %d/sec | ~%s min left   ' \
        $((DONE * 100 / TOTAL)) "$DONE" "$TOTAL" "$FAILED" "$RATE" "$ETA"
done
wait
echo
echo "Done in $(( $(date +%s) - START )) seconds."
finish