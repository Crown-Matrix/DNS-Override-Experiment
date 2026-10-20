#!/bin/bash

domain_list=(
    # =========================
    # Search / portals
    # =========================
    "google.com"
    "bing.com"
    "yahoo.com"
    "duckduckgo.com"
    "brave.com"
    "startpage.com"
    "ask.com"
    "aol.com"
    "ecosia.org"
    "yandex.com"
    "baidu.com"

    # =========================
    # Social media
    # =========================
    "facebook.com"
    "instagram.com"
    "twitter.com"
    "x.com"
    "reddit.com"
    "tiktok.com"
    "snapchat.com"
    "linkedin.com"
    "pinterest.com"
    "tumblr.com"
    "threads.net"
    "mastodon.social"
    "bluesky.app"
    "quora.com"
    "flickr.com"
    "weibo.com"
    "vk.com"
    "nextdoor.com"

    # =========================
    # Messaging / communication
    # =========================
    "discord.com"
    "discordapp.com"
    "telegram.org"
    "whatsapp.com"
    "signal.org"
    "messenger.com"
    "skype.com"
    "zoom.us"
    "slack.com"
    "teams.microsoft.com"
    "webex.com"
    "line.me"
    "kakao.com"
    "wechat.com"

    # =========================
    # Video / streaming
    # =========================
    "youtube.com"
    "youtu.be"
    "netflix.com"
    "hulu.com"
    "twitch.tv"
    "vimeo.com"
    "dailymotion.com"
    "peacocktv.com"
    "max.com"
    "disneyplus.com"
    "paramountplus.com"
    "primevideo.com"
    "crunchyroll.com"
    "pluto.tv"
    "tubi.tv"
    "plex.tv"
    "roku.com"
    "funimation.com"

    # =========================
    # Music
    # =========================
    "spotify.com"
    "soundcloud.com"
    "pandora.com"
    "music.apple.com"
    "music.youtube.com"
    "tidal.com"
    "deezer.com"
    "bandcamp.com"
    "last.fm"
    "iheartradio.com"

    # =========================
    # Gaming
    # =========================
    "steampowered.com"
    "steamcommunity.com"
    "store.steampowered.com"
    "epicgames.com"
    "roblox.com"
    "minecraft.net"
    "minecraftservices.com"
    "ea.com"
    "origin.com"
    "ubisoft.com"
    "ubisoftconnect.com"
    "riotgames.com"
    "leagueoflegends.com"
    "valorant.com"
    "blizzard.com"
    "battle.net"
    "xbox.com"
    "playstation.com"
    "nintendo.com"
    "itch.io"
    "gog.com"
    "gamestop.com"
    "battlefield.com"
    "callofduty.com"
    "bungie.net"
    "eldenring.com"

    # =========================
    # Gambling / betting
    # =========================
    "draftkings.com"
    "fanduel.com"
    "betmgm.com"
    "caesars.com"
    "bet365.com"
    "bovada.lv"
    "stake.com"
    "pokerstars.com"
    "888.com"
    "betway.com"
    "pointsbet.com"
    "barstoolsportsbook.com"

    # =========================
    # Adult-content domains
    # =========================
    "pornhub.com"
    "xvideos.com"
    "xhamster.com"
    "redtube.com"
    "youporn.com"
    "spankbang.com"
    "chaturbate.com"
    "onlyfans.com"
    "fansly.com"

    # =========================
    # Finance / investing / trading
    # =========================
    "webull.com"
    "robinhood.com"
    "fidelity.com"
    "schwab.com"
    "vanguard.com"
    "etrade.com"
    "interactivebrokers.com"
    "tdameritrade.com"
    "merrilledge.com"
    "acorns.com"
    "sofi.com"
    "betterment.com"
    "wealthfront.com"
    "public.com"
    "moomoo.com"
    "tradingview.com"
    "investing.com"
    "marketwatch.com"
    "seekingalpha.com"
    "barchart.com"
    "stocktwits.com"

    # =========================
    # Crypto
    # =========================
    "coinbase.com"
    "kraken.com"
    "binance.com"
    "crypto.com"
    "gemini.com"
    "blockchain.com"
    "bitstamp.net"
    "kucoin.com"
    "okx.com"
    "bybit.com"
    "metamask.io"
    "opensea.io"

    # =========================
    # Banking / payments
    # =========================
    "paypal.com"
    "venmo.com"
    "zellepay.com"
    "cash.app"
    "chase.com"
    "bankofamerica.com"
    "wellsfargo.com"
    "capitalone.com"
    "citibank.com"
    "usbank.com"
    "pnc.com"
    "ally.com"
    "discover.com"
    "americanexpress.com"
    "stripe.com"
    "square.com"

    # =========================
    # Shopping
    # =========================
    "amazon.com"
    "ebay.com"
    "walmart.com"
    "target.com"
    "bestbuy.com"
    "etsy.com"
    "aliexpress.com"
    "temu.com"
    "newegg.com"
    "wish.com"
    "wayfair.com"
    "homedepot.com"
    "lowes.com"
    "costco.com"
    "kohls.com"
    "macys.com"
    "nordstrom.com"
    "shein.com"
    "nike.com"
    "adidas.com"

    # =========================
    # File sharing / cloud storage
    # =========================
    "dropbox.com"
    "drive.google.com"
    "onedrive.com"
    "box.com"
    "mega.io"
    "mediafire.com"
    "4shared.com"
    "wetransfer.com"
    "sendspace.com"
    "zippyshare.com"
    "gofile.io"

    # =========================
    # VPN / proxy / circumvention
    # =========================
    "nordvpn.com"
    "expressvpn.com"
    "surfshark.com"
    "protonvpn.com"
    "privateinternetaccess.com"
    "cyberghostvpn.com"
    "tunnelbear.com"
    "windscribe.com"
    "hide.me"
    "hotspotshield.com"
    "psiphon.ca"
    "torproject.org"
    "proton.me"

    # =========================
    # Developer / code
    # =========================
    "github.com"
    "raw.githubusercontent.com"
    "objects.githubusercontent.com"
    "github-releases.githubusercontent.com"
    "avatars.githubusercontent.com"
    "copilot-proxy.githubusercontent.com"
    "copilot-telemetry.githubusercontent.com"
    "origin-tracker.githubusercontent.com"
    "gitlab.com"
    "bitbucket.org"
    "stackoverflow.com"
    "stackexchange.com"
    "npmjs.com"
    "pypi.org"
    "crates.io"
    "packagist.org"
    "docker.com"
    "hub.docker.com"
    "kaggle.com"
    "replit.com"
    "codepen.io"
    "jsfiddle.net"
    "codesandbox.io"
    "glitch.com"
    "vercel.com"
    "netlify.com"
    "render.com"
    "heroku.com"
    "digitalocean.com"
    "linode.com"
    "python.org"
    "rust-lang.org"
    "cplusplus.com"

    # =========================
    # AI
    # =========================
    "openai.com"
    "chatgpt.com"
    "anthropic.com"
    "claude.ai"
    "gemini.google.com"
    "copilot.microsoft.com"
    "perplexity.ai"
    "huggingface.co"
    "character.ai"
    "poe.com"
    "jasper.ai"
    "midjourney.com"
    "stability.ai"
    "replicate.com"

    # =========================
    # Education
    # =========================
    "wikipedia.org"
    "khanacademy.org"
    "coursera.org"
    "edx.org"
    "quizlet.com"
    "chegg.com"
    "coursehero.com"
    "studocu.com"
    "brainly.com"
    "quizizz.com"
    "kahoot.com"
    "duolingo.com"
    "udemy.com"
    "skillshare.com"
    "brilliant.org"

    # =========================
    # News
    # =========================
    "cnn.com"
    "bbc.com"
    "nytimes.com"
    "washingtonpost.com"
    "foxnews.com"
    "npr.org"
    "reuters.com"
    "apnews.com"
    "usatoday.com"
    "nbcnews.com"
    "abcnews.go.com"
    "cbsnews.com"
    "newsweek.com"
    "politico.com"
    "theguardian.com"
    "axios.com"
    "vice.com"
    "buzzfeed.com"

    # =========================
    # Forums / communities
    # =========================
    "4chan.org"
    "8kun.top"
    "lemmy.world"
    "discourse.org"
    "medium.com"
    "substack.com"
    "patreon.com"
    "archiveofourown.org"
    "fanfiction.net"

    # =========================
    # Torrents / file sharing
    # =========================
    "thepiratebay.org"
    "1337x.to"
    "torrentgalaxy.to"
    "rutracker.org"
    "nyaa.si"
    "limetorrents.lol"

    # =========================
    # Proxies / URL shorteners
    # =========================
    "bit.ly"
    "tinyurl.com"
    "t.co"
    "goo.gl"
    "is.gd"
    "rebrand.ly"

    # =========================
    # Travel / transportation
    # =========================
    "uber.com"
    "lyft.com"
    "airbnb.com"
    "expedia.com"
    "booking.com"
    "tripadvisor.com"
    "kayak.com"
    "southwest.com"
    "aa.com"
    "delta.com"
    "united.com"

    # =========================
    # Misc. commonly restricted
    # =========================
    "craigslist.org"
    "archive.org"
    "imdb.com"
    "rottentomatoes.com"
    "weather.com"
    "speedtest.net"
    "9gag.com"
    "imgur.com"
    "giphy.com"
    "tenor.com"
    "pastebin.com"
    "paste.ee"
    "archive.ph"
)

for domain in "${domain_list[@]}"; do
    if ! dig +short "$domain" A 2>/dev/null | grep -q .; then
        echo "UNRESOLVED: $domain"
    fi
done