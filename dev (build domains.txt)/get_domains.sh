#!/bin/bash
# Builds domains.txt: one domain per line, de-duplicated.
# Sources: Tranco top-N, builtin_domains.txt (if present), category blocklists from GitHub.
#
# Usage: ./get_domains_all.sh                 (Tranco top 1M + everything else)
#        TRANCO_N=100000 ./get_domains_all.sh (smaller Tranco slice)
#        OUT=mylist.txt ./get_domains_all.sh

TRANCO_N="${TRANCO_N:-1000000}"
OUT="${OUT:-domains.txt}"
HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
: > "$WORK/all.txt"

# Tranco popularity list
echo "Tranco top $TRANCO_N..."
if curl -fsSL https://tranco-list.eu/top-1m.csv.zip -o "$WORK/top.zip"; then
    unzip -p "$WORK/top.zip" | head -n "$TRANCO_N" | cut -d, -f2 >> "$WORK/all.txt"
else
    echo "  Tranco download failed"
fi

# your hand-picked list
[ -f "$HERE/builtin_domains.txt" ] && cat "$HERE/builtin_domains.txt" >> "$WORK/all.txt"

# hosts-format blocklists (second column is the domain)
BLP=https://raw.githubusercontent.com/blocklistproject/Lists/master
SB=https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates
for url in $BLP/porn.txt $BLP/gambling.txt $BLP/piracy.txt $BLP/torrent.txt $BLP/crypto.txt \
           $BLP/drugs.txt $BLP/facebook.txt $BLP/tiktok.txt $BLP/twitter.txt $BLP/whatsapp.txt \
           $BLP/youtube.txt $SB/porn-only/hosts $SB/gambling-only/hosts $SB/social-only/hosts \
           $SB/fakenews-only/hosts; do
    echo "${url##*master/}"
    curl -fsSL "$url" | awk '$1=="0.0.0.0" || $1=="127.0.0.1" {print $2}' >> "$WORK/all.txt"
done

# plain domain lists
for name in nsfw gambling social anti.piracy doh-vpn-proxy-bypass dyndns; do
    echo "hagezi $name"
    curl -fsSL "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/$name-onlydomains.txt" \
      | grep -v '^#' >> "$WORK/all.txt"
done

# clean: lowercase, valid hostnames only, de-duplicate
tr -d '\r' < "$WORK/all.txt" | tr 'A-Z' 'a-z' \
  | grep -E '^([a-z0-9]([a-z0-9_-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$' | sort -u > "$OUT"

echo "Saved $(wc -l < "$OUT" | tr -d ' ') domains -> $OUT"