#!/bin/bash
#
# Usage: sudo ./auto_domain_configs.sh [--force] input.txt
#   input.txt  lines like "example.com FAILED REFUSED"
#   --force    overwrite existing resolver files (default: skip them)

PATH=/usr/bin:/bin:/usr/sbin:/sbin
umask 022

RESOLVER_DIR="/etc/resolver"
SKIPPED_NAME="skipped_auto_domain_configs.txt"

usage() { echo "Usage: sudo $0 [--force] input.txt"; exit 1; }

# 1. macOS + administrator check
[[ "$(uname -s)" == "Darwin" ]] || { echo "This script only runs on macOS."; exit 1; }
if (( EUID != 0 )); then
    echo "Please run this script with sudo."
    exit 1
fi

# 2. Arguments
force=0
input_file=""
for arg in "$@"; do
    case "$arg" in
        --force) force=1 ;;
        -*) usage ;;
        *) [[ -z "$input_file" ]] || usage; input_file="$arg" ;;
    esac
done

# 3. Read the input file
[[ -n "$input_file" ]] || usage
[[ -f "$input_file" && -r "$input_file" ]] || { echo "Cannot read input file: $input_file"; exit 1; }

# Keep only "<domain> FAILED REFUSED" lines; lower-case; drop duplicates.
domains=$(awk 'NF == 3 && tolower($2) == "failed" && tolower($3) == "refused" {
                   d = tolower($1); sub(/\.$/, "", d); if (!seen[d]++) print d }' "$input_file")
if [[ -z "$domains" ]]; then
    echo "No 'FAILED REFUSED' lines found in $input_file."
    exit 1
fi

# 4. Confirm
echo "$(wc -l <<< "$domains" | tr -d ' ') domain(s) found in '$input_file'."
read -r -p "Does '$input_file' contain ALL the data you need? (y/n): " confirm
if [[ "$confirm" == [yY] ]]; then
    echo "Confirmed!"
else
    echo "Cancelled."
    exit 0
fi

mkdir -p "$RESOLVER_DIR" || exit 1

# 5. Write one resolver file per domain
skipped=()
written=0
failed=0
tmp="${RESOLVER_DIR%/*}/.resolver.tmp.$$"
trap 'rm -f "$tmp"' EXIT

while read -r domain; do
    # Plain hostnames only: stops "../x" or "a/b" from leaving /etc/resolver.
    if [[ ! "$domain" =~ ^[a-z0-9_]([a-z0-9_.-]*[a-z0-9_])?$ || "$domain" == *..* ]]; then
        echo "Skipping invalid domain: $domain"
        continue
    fi

    target="$RESOLVER_DIR/$domain"
    if [[ ( -e "$target" || -L "$target" ) && $force -eq 0 ]]; then
        echo "Skipping: $domain already exists."
        skipped+=("$domain")
        continue
    fi

    # Write a temp file, then rename it over the target, so an existing file is
    # never lost if the write fails.
    if [[ ! -d "$target" ]] && echo "nameserver 1.1.1.1" > "$tmp" && mv -f "$tmp" "$target"; then
        echo "Successfully routed: $domain -> 1.1.1.1"
        written=$((written + 1))
    else
        echo "Failed to write resolver for: $domain"
        failed=$((failed + 1))
    fi
done <<< "$domains"

# 6. Offer to save the skipped domains (as the user who ran sudo, never root)
if (( ${#skipped[@]} > 0 )); then
    echo
    echo "Domains that were not overwritten:"
    printf '  %s\n' "${skipped[@]}"
    read -r -p "Save this list as $SKIPPED_NAME on your Desktop? (y/n): " save_confirm

    if [[ "$save_confirm" == [yY] ]]; then
        user="$SUDO_USER"
        home=$(dscl . -read "/Users/$user" NFSHomeDirectory 2>/dev/null |
            sed -e 's/^NFSHomeDirectory:[[:space:]]*//' -e 's/^[[:space:]]*//' -e '/^$/d' | head -n 1)

        if [[ -z "$user" || "$user" == "root" || "$home" != /* || "$home" == "/var/root" || ! -d "$home" ]]; then
            echo "Could not find your home directory; not saving the list."
        else
            dest="$home/Desktop"
            if [[ ! -d "$dest" ]]; then
                echo "Desktop folder not found: $dest"
                read -r -p "Save it in $home instead? (y/n): " home_confirm
                if [[ "$home_confirm" == [yY] ]]; then dest="$home"; else dest=""; fi
            fi
            if [[ -n "$dest" ]]; then
                if printf '%s\n' "${skipped[@]}" |
                    (cd "$home" && sudo -u "$user" tee "$dest/$SKIPPED_NAME" > /dev/null) 2>/dev/null; then
                    echo "Saved skipped domains to: $dest/$SKIPPED_NAME"
                else
                    echo "Failed to save the skipped domains."
                fi
            fi
        fi
    fi
fi

# 7. Flush the DNS cache and report
echo
if dscacheutil -flushcache && killall -HUP mDNSResponder; then
    flushed=1
    echo "DNS cache flushed."
else
    flushed=0
    echo "WARNING: could not flush the DNS cache."
fi

stats="[$written written, ${#skipped[@]} skipped"
(( failed > 0 )) && stats="$stats, $failed failed"
echo "$stats]"

if (( failed == 0 && flushed )); then
    echo "SUCCESS: finished with no errors."
    exit 0
fi
echo "FAILED: finished with errors (see above)."
exit 1