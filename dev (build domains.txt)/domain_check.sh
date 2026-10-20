#!/usr/bin/env bash
#
# domain_check.sh - test which domains resolve (or are blocked) on this network.
#
# Combines:
#   1. A curated built-in list (your original categories, expanded)
#   2. Tranco top-N most popular sites            (tranco-list.eu)
#   3. Community category blocklists from GitHub  (StevenBlack, BlockList Project, Hagezi)
#
# Usage:
#   ./domain_check.sh                       # defaults
#   TRANCO_N=100000 JOBS=200 ./domain_check.sh
#   RESOLVER=1.1.1.1 ./domain_check.sh      # query a specific DNS server
#   OFFLINE=1 ./domain_check.sh             # built-in list only, no downloads
#   SHOW_OK=1 ./domain_check.sh             # also print domains that resolved
#
# Output:
#   stdout        -> "UNRESOLVED: domain (STATUS)" for every non-OK domain
#   results.tsv   -> every domain: STATUS <tab> domain <tab> ips
#   summary at the end, broken down by status
#
# Statuses:
#   OK         resolved to a real IP
#   SINKHOLE   resolved to 0.0.0.0 / 127.x  (typical DNS-filter block)
#   NXDOMAIN   name doesn't exist (blocked by filter OR simply a dead domain)
#   REFUSED    resolver refused (typical filter block)
#   SERVFAIL   resolver error
#   TIMEOUT    no answer
#   NOANSWER   NOERROR but no A record
#
# NOTE: blocklist domains are often dead. NXDOMAIN on those does not prove a
# block - compare against a known-unfiltered resolver (RESOLVER=1.1.1.1) to be sure.

set -u

# ---------- config (override via environment) ----------
TRANCO_N="${TRANCO_N:-10000}"        # how many top Tranco domains (0 = skip)
PER_LIST_MAX="${PER_LIST_MAX:-0}"    # cap per blocklist (0 = no cap)
JOBS="${JOBS:-100}"                  # parallel dig workers
RESOLVER="${RESOLVER:-}"             # e.g. 1.1.1.1 (empty = system resolver)
OFFLINE="${OFFLINE:-0}"
SHOW_OK="${SHOW_OK:-0}"
OUT_FILE="${OUT_FILE:-results.tsv}"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

for bin in dig curl awk xargs; do
    command -v "$bin" >/dev/null 2>&1 || { echo "Missing required tool: $bin" >&2; exit 1; }
done

# ---------- 1. curated built-in list ----------
read -r -d '' BUILTIN <<'EOF'
google.com bing.com yahoo.com duckduckgo.com brave.com startpage.com ask.com aol.com ecosia.org yandex.com baidu.com
qwant.com search.brave.com kagi.com naver.com daum.net sogou.com seznam.cz

facebook.com instagram.com twitter.com x.com reddit.com tiktok.com snapchat.com linkedin.com pinterest.com tumblr.com
threads.net mastodon.social bluesky.app quora.com flickr.com weibo.com vk.com nextdoor.com telegram.me t.me
bsky.app truthsocial.com gab.com parler.com rumble.com minds.com ok.ru douyin.com xiaohongshu.com bereal.com
clubhouse.com tinder.com bumble.com hinge.co grindr.com okcupid.com match.com badoo.com meetme.com

discord.com discordapp.com telegram.org whatsapp.com signal.org messenger.com skype.com zoom.us slack.com
teams.microsoft.com webex.com line.me kakao.com wechat.com viber.com element.io matrix.org gotomeeting.com
meet.google.com groupme.com omegle.com chatroulette.com

youtube.com youtu.be netflix.com hulu.com twitch.tv vimeo.com dailymotion.com peacocktv.com max.com disneyplus.com
paramountplus.com primevideo.com crunchyroll.com pluto.tv tubi.tv plex.tv roku.com funimation.com hbomax.com
appletv.apple.com tv.apple.com kick.com bilibili.com iqiyi.com youku.com viki.com curiositystream.com
discoveryplus.com sling.com fubo.tv philo.com vudu.com crackle.com espn.com nba.com nfl.com mlb.com nhl.com

spotify.com soundcloud.com pandora.com music.apple.com music.youtube.com tidal.com deezer.com bandcamp.com
last.fm iheartradio.com audiomack.com mixcloud.com napster.com siriusxm.com tunein.com genius.com

steampowered.com steamcommunity.com store.steampowered.com epicgames.com roblox.com minecraft.net minecraftservices.com
ea.com origin.com ubisoft.com ubisoftconnect.com riotgames.com leagueoflegends.com valorant.com blizzard.com
battle.net xbox.com playstation.com nintendo.com itch.io gog.com gamestop.com battlefield.com callofduty.com
bungie.net eldenring.com fortnite.com rockstargames.com supercell.com king.com zynga.com garena.com
mihoyo.com hoyoverse.com genshin.hoyoverse.com playstation.net xboxlive.com nintendo.net twitch.tv
gamespot.com ign.com kotaku.com polygon.com pcgamer.com curseforge.com modrinth.com nexusmods.com
fandom.com miniclip.com poki.com crazygames.com y8.com newgrounds.com kongregate.com coolmathgames.com
armorgames.com addictinggames.com friv.com kizi.com

draftkings.com fanduel.com betmgm.com caesars.com bet365.com bovada.lv stake.com pokerstars.com 888.com betway.com
pointsbet.com barstoolsportsbook.com williamhill.com paddypower.com ladbrokes.com unibet.com betfair.com
espnbet.com fanatics.com betrivers.com hardrock.bet bwin.com 1xbet.com 22bet.com mostbet.com betonline.ag
mybookie.ag sportsbetting.ag betus.com.pa ignitioncasino.eu slotomania.com jackpotcity.com

pornhub.com xvideos.com xhamster.com redtube.com youporn.com spankbang.com chaturbate.com onlyfans.com fansly.com
xnxx.com tube8.com eporner.com porn.com brazzers.com bangbros.com stripchat.com bongacams.com cam4.com
livejasmin.com myfreecams.com motherless.com thumbzilla.com beeg.com tnaflix.com rule34.xxx e-hentai.org
nhentai.net hentaihaven.xxx literotica.com

webull.com robinhood.com fidelity.com schwab.com vanguard.com etrade.com interactivebrokers.com tdameritrade.com
merrilledge.com acorns.com sofi.com betterment.com wealthfront.com public.com moomoo.com tradingview.com
investing.com marketwatch.com seekingalpha.com barchart.com stocktwits.com finance.yahoo.com bloomberg.com
cnbc.com wsj.com ft.com forbes.com fool.com morningstar.com zacks.com finviz.com tastytrade.com tradestation.com
ally.com/invest firstrade.com stash.com m1.com

coinbase.com kraken.com binance.com crypto.com gemini.com blockchain.com bitstamp.net kucoin.com okx.com bybit.com
metamask.io opensea.io binance.us bitfinex.com huobi.com gate.io mexc.com bitget.com bitmex.com uniswap.org
pancakeswap.finance etherscan.io coinmarketcap.com coingecko.com coindesk.com cointelegraph.com phantom.app
ledger.com trezor.io blur.io rarible.com

paypal.com venmo.com zellepay.com cash.app chase.com bankofamerica.com wellsfargo.com capitalone.com citibank.com
usbank.com pnc.com ally.com discover.com americanexpress.com stripe.com square.com wise.com revolut.com
chime.com klarna.com affirm.com payoneer.com skrill.com neteller.com westernunion.com moneygram.com
truist.com tdbank.com regions.com citizensbank.com hsbc.com barclays.co.uk lloydsbank.com natwest.com

amazon.com ebay.com walmart.com target.com bestbuy.com etsy.com aliexpress.com temu.com newegg.com wish.com
wayfair.com homedepot.com lowes.com costco.com kohls.com macys.com nordstrom.com shein.com nike.com adidas.com
alibaba.com taobao.com jd.com rakuten.com mercadolibre.com shopify.com walgreens.com cvs.com ikea.com
zara.com hm.com uniqlo.com sephora.com ulta.com chewy.com petco.com gap.com oldnavy.com

dropbox.com drive.google.com onedrive.com box.com mega.io mediafire.com 4shared.com wetransfer.com sendspace.com
zippyshare.com gofile.io icloud.com pcloud.com sync.com mega.nz anonfiles.com file.io transfer.sh

nordvpn.com expressvpn.com surfshark.com protonvpn.com privateinternetaccess.com cyberghostvpn.com tunnelbear.com
windscribe.com hide.me hotspotshield.com psiphon.ca torproject.org proton.me mullvad.net ivpn.net ipvanish.com
purevpn.com vyprvpn.com hidemyass.com zenmate.com betternet.co lantern.io getlantern.org
hidemy.name proxysite.com croxyproxy.com kproxy.com hide.me/en/proxy

github.com raw.githubusercontent.com objects.githubusercontent.com github-releases.githubusercontent.com
avatars.githubusercontent.com copilot-proxy.githubusercontent.com copilot-telemetry.githubusercontent.com
origin-tracker.githubusercontent.com gitlab.com bitbucket.org stackoverflow.com stackexchange.com npmjs.com
pypi.org crates.io packagist.org docker.com hub.docker.com kaggle.com replit.com codepen.io jsfiddle.net
codesandbox.io glitch.com vercel.com netlify.com render.com heroku.com digitalocean.com linode.com python.org
rust-lang.org cplusplus.com aws.amazon.com azure.microsoft.com cloud.google.com cloudflare.com fly.io railway.app
supabase.com firebase.google.com rubygems.org nuget.org maven.org golang.org go.dev nodejs.org
developer.mozilla.org w3schools.com geeksforgeeks.org leetcode.com hackerrank.com codeforces.com
gist.github.com pkg.go.dev jsdelivr.net unpkg.com cdnjs.com

openai.com chatgpt.com anthropic.com claude.ai gemini.google.com copilot.microsoft.com perplexity.ai huggingface.co
character.ai poe.com jasper.ai midjourney.com stability.ai replicate.com grok.com x.ai mistral.ai cohere.com
deepseek.com chat.deepseek.com you.com phind.com runwayml.com elevenlabs.io suno.com udio.com leonardo.ai
civitai.com janitorai.com chub.ai crushon.ai candy.ai replika.com pi.ai notebooklm.google.com

wikipedia.org khanacademy.org coursera.org edx.org quizlet.com chegg.com coursehero.com studocu.com brainly.com
quizizz.com kahoot.com duolingo.com udemy.com skillshare.com brilliant.org canvas.instructure.com
blackboard.com schoology.com classroom.google.com docs.google.com gradescope.com desmos.com wolframalpha.com
grammarly.com scribd.com slideshare.net sparknotes.com cliffsnotes.com shmoop.com bartleby.com
nerdwallet.com turnitin.com edpuzzle.com nearpod.com prodigygame.com ixl.com

cnn.com bbc.com nytimes.com washingtonpost.com foxnews.com npr.org reuters.com apnews.com usatoday.com nbcnews.com
abcnews.go.com cbsnews.com newsweek.com politico.com theguardian.com axios.com vice.com buzzfeed.com
huffpost.com dailymail.co.uk breitbart.com infowars.com dailywire.com msnbc.com thehill.com vox.com
theatlantic.com newyorker.com time.com economist.com aljazeera.com rt.com sputniknews.com tass.com
zerohedge.com theintercept.com slate.com salon.com nypost.com latimes.com chicagotribune.com

4chan.org 8kun.top lemmy.world discourse.org medium.com substack.com patreon.com archiveofourown.org
fanfiction.net wattpad.com deviantart.com artstation.com behance.net dribbble.com kiwifarms.net
somethingawful.com resetera.com neogaf.com voat.co tapatalk.com boards.4channel.org 4channel.org
kemono.party kemono.su coomer.party coomer.su

thepiratebay.org 1337x.to torrentgalaxy.to rutracker.org nyaa.si limetorrents.lol yts.mx eztv.re rarbg.to
kickasstorrents.to torlock.com zooqle.com bt4g.org btdig.com fitgirl-repacks.site dodi-repacks.site
sci-hub.se libgen.is libgen.rs z-lib.org annas-archive.org openlibrary.org

bit.ly tinyurl.com t.co goo.gl is.gd rebrand.ly ow.ly buff.ly cutt.ly shorturl.at tiny.cc v.gd bl.ink

uber.com lyft.com airbnb.com expedia.com booking.com tripadvisor.com kayak.com southwest.com aa.com delta.com
united.com jetblue.com alaskaair.com spirit.com frontier.com hotels.com vrbo.com priceline.com orbitz.com
skyscanner.com google.com/travel doordash.com ubereats.com grubhub.com instacart.com yelp.com opentable.com

craigslist.org archive.org imdb.com rottentomatoes.com weather.com speedtest.net 9gag.com imgur.com giphy.com
tenor.com pastebin.com paste.ee archive.ph archive.today web.archive.org wayback.archive.org ghostbin.com
hastebin.com rentry.co telegra.ph anonymouse.org 4plebs.org fmovies.to 123movies.com putlocker.vip
soap2day.to solarmovie.pe cuevana3.io hianime.to zoro.to gogoanime.cl 9anime.to aniwatch.to kissanime.ru
mangadex.org mangakakalot.com webtoons.com tapas.io wuxiaworld.com novelupdates.com

gmail.com mail.google.com outlook.com outlook.live.com hotmail.com mail.yahoo.com protonmail.com tutanota.com
zoho.com icloud.com mail.com gmx.com fastmail.com guerrillamail.com 10minutemail.com temp-mail.org mailinator.com
yopmail.com sharklasers.com maildrop.cc getnada.com tempmail.email

microsoft.com office.com live.com apple.com adobe.com salesforce.com oracle.com ibm.com intel.com nvidia.com
amd.com dell.com hp.com lenovo.com samsung.com sony.com netflix.net notion.so trello.com asana.com airtable.com
figma.com canva.com miro.com monday.com atlassian.net jira.com confluence.com dropboxpaper.com evernote.com
EOF

# ---------- helpers ----------
log() { echo "[*] $*" >&2; }

# normalise: lowercase, strip CR/comments/paths, keep valid hostnames only
normalize() {
    tr -d '\r' \
    | tr 'A-Z' 'a-z' \
    | sed -E 's/#.*$//; s#^https?://##; s#/.*$##; s/^\*\.//; s/^\.+//; s/[[:space:]]+$//' \
    | grep -E '^([a-z0-9]([a-z0-9_-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$' \
    || true
}

# hosts-file format: "0.0.0.0 domain" / "127.0.0.1 domain"
hosts_to_domains() {
    awk '$1=="0.0.0.0" || $1=="127.0.0.1" {print $2}' \
    | grep -Ev '^(localhost|localhost\.localdomain|local|broadcasthost|ip6-.*|0\.0\.0\.0)$' \
    | normalize
}

cap() { if [ "$PER_LIST_MAX" -gt 0 ]; then head -n "$PER_LIST_MAX"; else cat; fi; }

fetch() { curl -fsSL --retry 2 --connect-timeout 10 --max-time 120 "$1" 2>/dev/null; }

fetch_hosts_list()  { # name url
    log "fetching $1"
    fetch "$2" | hosts_to_domains | cap >> "$WORKDIR/all.txt" || log "  failed: $1"
}
fetch_domain_list() { # name url
    log "fetching $1"
    fetch "$2" | normalize | cap >> "$WORKDIR/all.txt" || log "  failed: $1"
}

# ---------- build the domain list ----------
: > "$WORKDIR/all.txt"

log "loading built-in list"
printf '%s\n' "$BUILTIN" | tr -s '[:space:]' '\n' | normalize >> "$WORKDIR/all.txt"

if [ "$OFFLINE" != "1" ]; then
    # Tranco top sites
    if [ "$TRANCO_N" -gt 0 ]; then
        log "fetching Tranco top $TRANCO_N"
        if command -v unzip >/dev/null 2>&1; then
            fetch "https://tranco-list.eu/top-1m.csv.zip" > "$WORKDIR/tranco.zip" \
              && unzip -p "$WORKDIR/tranco.zip" 2>/dev/null \
                   | head -n "$TRANCO_N" | cut -d, -f2 | normalize >> "$WORKDIR/all.txt" \
              || log "  failed: Tranco"
        else
            log "  'unzip' not installed - skipping Tranco"
        fi
    fi

    # StevenBlack category hosts
    SB="https://raw.githubusercontent.com/StevenBlack/hosts/master"
    fetch_hosts_list "StevenBlack porn"     "$SB/alternates/porn-only/hosts"
    fetch_hosts_list "StevenBlack gambling" "$SB/alternates/gambling-only/hosts"
    fetch_hosts_list "StevenBlack social"   "$SB/alternates/social-only/hosts"
    fetch_hosts_list "StevenBlack fakenews" "$SB/alternates/fakenews-only/hosts"

    # BlockList Project categories (hosts format)
    BLP="https://raw.githubusercontent.com/blocklistproject/Lists/master"
    for cat in porn gambling piracy torrent crypto drugs facebook tiktok twitter whatsapp youtube \
               ; do
        fetch_hosts_list "BlockList Project: $cat" "$BLP/$cat.txt"
    done

    # Hagezi (plain domain lists)
    HZ="https://raw.githubusercontent.com/hagezi/dns-blocklists/main/domains"
    for cat in nsfw gambling social anti.piracy doh-vpn-proxy-bypass dyndns; do
        fetch_domain_list "Hagezi: $cat" "$HZ/$cat.txt"
    done
fi

sort -u "$WORKDIR/all.txt" > "$WORKDIR/domains.txt"
TOTAL=$(wc -l < "$WORKDIR/domains.txt" | tr -d ' ')
log "total unique domains: $TOTAL  (workers: $JOBS, resolver: ${RESOLVER:-system})"

# ---------- resolution check ----------
check_domain() {
    local d="$1" out status ips st
    out=$(dig +noall +comments +answer +time=2 +tries=2 ${RESOLVER:+@"$RESOLVER"} A "$d" 2>/dev/null)
    status=$(printf '%s\n' "$out" | sed -n 's/.*status: \([A-Z]*\).*/\1/p' | head -n1)
    ips=$(printf '%s\n' "$out" | awk '$4=="A"{print $5}' | paste -sd, -)

    if [ -z "$status" ]; then
        st="TIMEOUT"
    elif [ "$status" = "NOERROR" ]; then
        if [ -z "$ips" ]; then
            st="NOANSWER"
        elif ! printf '%s\n' "$ips" | tr ',' '\n' | grep -qvE '^(0\.0\.0\.0|127\.[0-9.]+)$'; then
            st="SINKHOLE"
        else
            st="OK"
        fi
    else
        st="$status"   # NXDOMAIN / SERVFAIL / REFUSED / ...
    fi
    printf '%s\t%s\t%s\n' "$st" "$d" "$ips"
}
export -f check_domain
export RESOLVER

log "resolving..."
xargs < "$WORKDIR/domains.txt" -P "$JOBS" -I{} bash -c 'check_domain "$1"' _ {} > "$OUT_FILE"

# ---------- report ----------
while IFS=$'\t' read -r st d ips; do
    if [ "$st" != "OK" ]; then
        echo "UNRESOLVED: $d ($st)"
    elif [ "$SHOW_OK" = "1" ]; then
        echo "OK: $d"
    fi
done < <(sort -t$'\t' -k1,1 -k2,2 "$OUT_FILE")

echo >&2
echo "=========== SUMMARY ===========" >&2
cut -f1 "$OUT_FILE" | sort | uniq -c | sort -rn | awk '{printf "  %-10s %s\n", $2, $1}' >&2
echo "  TOTAL      $TOTAL" >&2
echo "Full results: $OUT_FILE" >&2