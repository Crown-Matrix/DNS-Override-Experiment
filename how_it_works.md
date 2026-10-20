# Per-domain DNS with /etc/resolver (webull.com)

Documented: 2026-09-29
Last Reviewed: 2026-10-20

## Summary

A local campus Wi-Fi's DNS servers answer `REFUSED` for `webull.com`, so the site fails to load (`DNS_PROBE_FINISHED_NXDOMAIN` in Chrome). To work around this, a single file in `/etc/resolver/` sends lookups for that one domain to Cloudflare (`1.1.1.1`). All other domains keep using the network's normal DNS.

This is the only DNS change on the machine. Wi-Fi DNS is set to automatic, and CoreDNS has been removed.

## How it works

macOS supports per-domain DNS rules. Any file placed in `/etc/resolver/` is treated as a rule where:

- The **filename** is the domain the rule applies to.
- The **contents** say which DNS server to use for that domain.

The file created here:

```
/etc/resolver/webull.com
```

Contents:

```
nameserver 1.1.1.1
```

When an app asks for `webull.com`, `www.webull.com`, `app.webull.com`, or any other subdomain, macOS sends the query to `1.1.1.1` instead of the Wi-Fi's DNS servers. Every other domain still goes to the servers the network provides.

Why this approach and not changing Wi-Fi DNS:

- macOS treats `NXDOMAIN` and `REFUSED` as final answers. It does not retry the next server in the list, so a "local first, Cloudflare second" server list does not fall back the way you might expect.
- Setting Cloudflare as the main DNS breaks internal-only names on the campus network.
- A per-domain rule fixes only the broken domain and leaves everything else untouched.

## Setup

```bash
sudo mkdir -p /etc/resolver
echo "nameserver 1.1.1.1" | sudo tee /etc/resolver/webull.com
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
```

What each line does:

| Command | Purpose |
| --- | --- |
| `sudo mkdir -p /etc/resolver` | Creates the folder macOS checks for per-domain rules (no error if it already exists) |
| `echo ... \| sudo tee /etc/resolver/webull.com` | Creates the rule file containing `nameserver 1.1.1.1` (`sudo` is needed to write in `/etc`) |
| `sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder` | Clears the DNS cache and reloads the DNS service so the new rule is picked up |

## Verify it works

Ask the system resolver (the same path Chrome and other apps use):

```bash
dscacheutil -q host -a name webull.com
```

Expected: a list of `ip_address:` lines.

Confirm macOS registered the rule:

```bash
scutil --dns | grep -B1 -A4 'domain.*webull'
```

Expected: a resolver with `domain : webull.com` and `nameserver[0] : 1.1.1.1`.

List the rule files:

```bash
ls -la /etc/resolver/
```

Note: plain `dig webull.com` may bypass `/etc/resolver` on some setups. Use `dscacheutil` for a true test.

## Add another domain

Make one file per domain, named after the domain:

```bash
echo "nameserver 1.1.1.1" | sudo tee /etc/resolver/example.com
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
```

Some sites use extra domains for their apps, APIs, or CDN. If a page loads but data or charts do not, a second domain is probably being refused too. Add a file for it the same way.

## Undo

Remove the rule file and flush the cache:

```bash
sudo rm /etc/resolver/webull.com
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
```

To confirm it is gone:

```bash
ls -la /etc/resolver/
scutil --dns | grep -B1 -A4 'domain.*webull'
```

The second command should print nothing. If `/etc/resolver/` is now empty and you want to remove the folder too:

```bash
sudo rmdir /etc/resolver
```

## Check the rest of DNS is at default

```bash
networksetup -getdnsservers Wi-Fi
```

Expected: `There aren't any DNS Servers set on Wi-Fi.`

If it lists servers, reset it:

```bash
sudo networksetup -setdnsservers Wi-Fi Empty
```

## Troubleshooting

- **Chrome still shows the DNS error:** clear its cache at `chrome://net-internals/#dns`.
- **Chrome "Use secure DNS" is on:** Chrome then uses its own encrypted DNS and ignores `/etc/resolver`. Turn it off in Chrome settings under Privacy and security, Security.
- **The name resolves but the page will not load:** the network may also block the site by IP or through a web filter. DNS cannot fix that.
- **The rule seems ignored:** check the file name matches the domain exactly and that the contents are exactly `nameserver 1.1.1.1`. Then flush the cache again.
- **The rule is persistent:** it survives reboots and applies on every network. That is harmless here, since Cloudflare resolves the domain normally anywhere, but remove it if you no longer need it.

## Notes

- The `REFUSED` answer means the network's DNS is deliberately blocking the domain.
- Cloudflare can see lookups for the domains listed in `/etc/resolver/`. Nothing else is sent to it.
- `/etc/resolv.conf` is not used by macOS for DNS routing and is auto-generated. Do not edit it. Use `scutil --dns` to see the real configuration.