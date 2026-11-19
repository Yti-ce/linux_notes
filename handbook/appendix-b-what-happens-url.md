# Appendix B: What happens when you type a URL

*Day 21 (2026-11-19). One page, built from my own captures in [8.5](08-networking.md#85-dns), [8.6](08-networking.md#86-ports-and-connections) and [8.7](08-networking.md#87-http-and-https).*

Example: on Windows, open `https://ubuntu-lab/login`.

| # | Step | What happens | Where I saw it |
|---|---|---|---|
| 0 | **Parse the URL** | scheme `https` → port **443** (default); host `ubuntu-lab`; path `/login` | `curl -v`: `Host ubuntu-lab:443` |
| 1 | **DNS: name → IP** | check local **hosts** file first → else ask the DNS server (forwarder → recursive resolver → root → `.com` → authoritative). Answer cached for its TTL | `ubuntu-lab` → `192.168.207.130` from `C:\Windows\System32\drivers\etc\hosts`; `dig +trace` |
| 2 | **Where to send it** | same subnet? (/24 → yes) send directly; otherwise to the **default gateway**. **ARP** finds the MAC of the next hop | `ip route`, `ip neigh` (8.3, 8.4) |
| 3 | **TCP handshake** | client picks an ephemeral port → `[S]` `[S.]` `[.]` to port 443 | `tcpdump port 443`: packets 1–3 |
| 4 | **TLS handshake** | **ClientHello** (with the site name, SNI, in clear text) → server sends its **certificate** → client checks it against trusted CAs → keys agreed; everything after this is encrypted | packet 4 (448 B, `ubuntu-lab` visible), packet 6 (1380 B); self-signed → `SEC_E_UNTRUSTED_ROOT` unless `-k` |
| 5 | **HTTP request** (encrypted) | `GET /login HTTP/1.1` + `Host:` + other headers | `curl -v` `>` lines; in tcpdump only noise |
| 6 | **Server works** | nginx matches `listen 443` + `server_name`, finds the file under `root`, writes a line to `access.log` | `/var/log/nginx/access.log` |
| 7 | **HTTP response** (encrypted) | status line (`200 OK` / `404 Not Found`) + headers + body | `curl -v` `<` lines |
| 8 | **Close** | TLS `close_notify` → TCP `[F.]` `[F.]` `[.]` (or kept open for the next request: `keep-alive`) | last packets |
| 9 | **Browser renders** | parses HTML, then repeats steps 1–8 for every image / CSS / JS it references | — |

**In one breath (interview version):**
"The browser resolves the name to an IP through hosts and DNS, finds the route and the next-hop MAC with ARP, opens a TCP connection to port 443 with a three-way handshake, does a TLS handshake where the server proves its identity with a certificate and both sides agree on keys, then sends the HTTP request encrypted. The server answers with a status code, headers and the page; the connection is closed with FIN or kept alive, and the browser renders the page and fetches its other resources the same way."

**What someone on the path can still see with HTTPS:** IPs, ports, packet sizes and timing, and the site name (SNI). **What they can't:** path, query, headers, cookies, body.
