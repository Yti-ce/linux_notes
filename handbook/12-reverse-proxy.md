# 12. nginx reverse proxy and load balancing

*Day 27 (2026-11-24).* Until now nginx served files itself. In real setups it usually stands **in front of** application servers: clients only talk to nginx on 80/443, nginx passes each request to a backend and brings the answer back. With two or more backends it also spreads the load. This chapter starts two tiny backends, puts nginx in front with round robin, then kills the backends one by one and troubleshoots the `502`.

Config file in this repo: [`configs/nginx/lb-lab`](configs/nginx/lb-lab).

## 12.1 Concepts

**Reverse proxy.** Restaurant picture: the client (browser / curl) only talks to the **waiter** (nginx on port 80); the waiter takes the order to the **kitchen** (backend on 8001) and brings the food out. The client gets the content, but never sees **where** the backend is (IP, port, how many). Why bother:

- only one public port (ufw keeps only 22/80/443 open, [Chapter 11](11-firewall.md))
- backends can be replaced or added without clients noticing
- HTTPS can be handled once, on nginx

**Two separate TCP connections:**

```
Windows .207.1 ──connection 1──> nginx :80        nginx ──connection 2──> 127.0.0.1:8001 (backend A)
                                                                     └──> 127.0.0.1:8002 (backend B)
```

nginx opens connection 2 **itself**, so the backend sees nginx as the client. Here nginx and the backends are on the same machine and connection 2 goes over loopback `lo`, so the backend sees **127.0.0.1**. (If a backend were on another machine, it would see the nginx machine's IP, e.g. 192.168.50.10.) The real client IP is only in **nginx's** access log, or passed on as the headers `X-Real-IP` / `X-Forwarded-For`.

**Load balancing / round robin.** One kitchen is too busy, so open two; the waiter (nginx) hands orders out in turn: A, B, A, B… If one kitchen is down, orders go to the other.

> Interview line: *"A reverse proxy is the single entry point: clients talk to nginx, nginx opens its own connection to a backend and returns the response. With an upstream group it also load-balances, round robin by default, and skips a backend that refuses connections."*

## 12.2 Two backends

Python has a tiny built-in web server. Each backend gets its own folder with an `index.html` that says who it is, so curl shows which one answered.

```bash
mkdir -p ~/lb/a ~/lb/b
echo "backend A (8001)" > ~/lb/a/index.html
echo "backend B (8002)" > ~/lb/b/index.html
```

Start each one in **its own ssh window** (it runs in the foreground and prints one log line per request; `Ctrl+C` stops it):

```bash
python3 -m http.server 8001 --bind 127.0.0.1 --directory ~/lb/a     # window 2
python3 -m http.server 8002 --bind 127.0.0.1 --directory ~/lb/b     # window 3
```

| Part | Meaning | nginx equivalent |
|---|---|---|
| `-m http.server 8001` | run Python's web server, **listen** on port 8001 (wait for connections there) | `listen 80;` |
| `--directory ~/lb/a` | the website's files; `/` → `index.html` in this folder | `root /var/www/html;` |
| `--bind 127.0.0.1` | listen on loopback only: the VM itself can connect, outside can't, so nobody can skip nginx | `ss` shows `127.0.0.1:8001`, not `0.0.0.0:8001` ([8.6](08-networking.md#86-ports-and-connections)) |

Check (window 1):

```console
admin123@admin:~$ curl 127.0.0.1:8001
backend A (8001)
admin123@admin:~$ curl 127.0.0.1:8002
backend B (8002)
admin123@admin:~$ sudo ss -tlnp | grep 800        # "800" = search text, matches 8001 and 8002
LISTEN 0  5  127.0.0.1:8001  0.0.0.0:*  users:(("python3",pid=12628,fd=3))
LISTEN 0  5  127.0.0.1:8002  0.0.0.0:*  users:(("python3",pid=12634,fd=3))
```

Window 2 printed `127.0.0.1 - - [24/Nov/2026 05:02:37] "GET / HTTP/1.1" 200 -` (its access log).

## 12.3 nginx config

```bash
sudo nano /etc/nginx/sites-available/lb-lab
```

```nginx
upstream backends {
    zone backends 64k;
    server 127.0.0.1:8001;
    server 127.0.0.1:8002;
}

server {
    listen 80 default_server;
    server_name _;

    location / {
        proxy_pass http://backends;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

| Line | Meaning |
|---|---|
| `upstream backends { ... }` | a named group of backends |
| `zone backends 64k;` | shared memory so all worker processes share one round-robin counter (see 12.5) |
| `listen 80 default_server;` | serve port 80; any request no other site matches comes here |
| `proxy_pass http://backends;` | pass the request to the group (round robin by default) |
| `proxy_set_header X-Real-IP $remote_addr;` | add the real client IP from connection 1 as a header for the backend |

Enable it. Only one site may be `default_server` on port 80, so the `default` site's **link** is removed (the file in `sites-available/` stays, see the undo steps in [`configs/nginx/lb-lab`](configs/nginx/lb-lab)):

```bash
sudo rm /etc/nginx/sites-enabled/default
sudo ln -s /etc/nginx/sites-available/lb-lab /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx          # reload: new workers, open connections not cut
```

```console
admin123@admin:~$ ls -l /etc/nginx/sites-enabled/
https-lab -> /etc/nginx/sites-available/https-lab
lb-lab -> /etc/nginx/sites-available/lb-lab
```

**Change config → `nginx -t` → reload.** All three. Before the reload the backends got no requests at all: nginx was still running the old config.

## 12.4 Verify

From the VM (`localhost` = this machine; no port = 80 = nginx; the point is to go **through** nginx, not to 8001 directly):

```console
admin123@admin:~$ for i in 1 2 3 4 5 6; do curl -s localhost; done
backend A (8001)
backend B (8002)
backend A (8001)
backend B (8002)
backend A (8001)
backend B (8002)
```

From Windows:

```powershell
PS> 1..4 | % { curl.exe -s http://ubuntu-lab }
```

Two logs, two views:

| Log | Sees | Line |
|---|---|---|
| nginx `/var/log/nginx/access.log` (connection 1) | the **client**: `192.168.207.1` (Windows on VMnet8) | `192.168.207.1 - - [...] "GET / HTTP/1.1" 200 17 "-" "curl/8.22.0"` |
| backend A window (connection 2) | **nginx**: `127.0.0.1` | `127.0.0.1 - - [...] "GET / HTTP/1.0" 200 -` |

`HTTP/1.0` on the backend vs `HTTP/1.1` from curl: nginx talks HTTP/1.0 to backends by default, one more sign that connection 2 is nginx's own request.

## 12.5 Why the first run was A A B A

Without the `zone` line the first run gave `A A B A`, not `A B A B`.

```console
admin123@admin:~$ ps aux | grep nginx
root      1214  ...  nginx: master process /usr/sbin/nginx ...
www-data 11798  ...  nginx: worker process
www-data 11799  ...  nginx: worker process
```

nginx = 1 **master** (root, reads config, manages) + one **worker** per CPU (www-data, does the work); the VM has 2 CPUs → 2 workers. Without shared memory **each worker keeps its own "whose turn is next"**, and each new curl connection may land on either worker, so the order looks random although the total is still even. `zone backends 64k;` gives them one shared counter → strict A B A B.

How I knew the second test was not yet using `zone`: the worker start time was still `05:30`, the time of the previous reload. A reload replaces the workers (new PID, new start time), so after the reload they showed `05:35`.

## 12.6 Drill: backends die (502 Bad Gateway)

**Level 1: one backend down.** `Ctrl+C` in backend B's window.

```console
admin123@admin:~$ for i in 1 2 3 4 5 6; do curl -s localhost; done
backend A (8001)       ← ×6, and no error for the client
```

What nginx did: tried B → `Connection refused` → **retried A for the same request**, and marked B unavailable for 10 s (defaults `max_fails=1 fail_timeout=10s`); after that it tries B again. The failures are in `error.log`.

**Level 2: all backends down.** `Ctrl+C` in backend A's window too. Symptom: "the website doesn't open".

| Question | Command | Saw | Tells me |
|---|---|---|---|
| What does the user get? | `curl -i localhost` | `HTTP/1.1 502 Bad Gateway` | there **is** a status code, so nginx answered → problem is **behind** nginx |
| Is nginx alive? | `sudo systemctl status nginx` | `active (running)` | nginx itself is fine |
| Why 502? | `tail -n 20 /var/log/nginx/error.log` | `connect() failed (111: Connection refused) while connecting to upstream, ... upstream: "http://127.0.0.1:8001/"` and the same for `:8002`, both `*73` | request 73 tried **both** backends, both refused → nobody listening there |
| What's listening now? | `sudo ss -tlnp \| grep 800` | (empty) | backends not running (not a wrong port or wrong bind) |
| Fix | restart both backends (↑ in their windows) | `ss` shows `127.0.0.1:8001` / `:8002` | — |
| Verify | 6 × `curl -s localhost` | `A A B A B A` | back; the first two A's = B still in its 10 s "unavailable" time |

**Why `ss` when the log already says refused:** the log is from the past, and `refused` only says nobody listens **at that address**. The same message comes from: backend not started, backend on the wrong port (8003), or backend bound to the wrong address (`.207.50` instead of `127.0.0.1`). Three different fixes; `ss` shows which one, **now**. Inference → evidence → then fix.

| Code | Meaning |
|---|---|
| no status code, `curl: (7) ... Connection refused` | nginx itself is down (nothing on 80) |
| `502 Bad Gateway` | nginx alive; the backend refused / gave a bad answer → check backends |
| `504 Gateway Timeout` | nginx alive; the backend is too slow |

> One line: **502 → nginx alive → `error.log` `upstream:` → `ss` on the backend port.**

## 12.7 Checklist

- [x] Two backends on `127.0.0.1:8001` / `:8002` (loopback only)
- [x] `lb-lab` with `upstream` + `zone`, `default` link removed, `nginx -t`, reload
- [x] Strict A/B round robin from the VM and from Windows
- [x] Client IP in nginx `access.log`, `127.0.0.1` in backend logs
- [x] One backend down: no client errors; all down: `502`, found and fixed via `error.log` + `ss`
- [ ] The Python backends run in the foreground and die with their ssh windows. Fine for a lab; a real backend would be a systemd service ([Chapter 4](04-systemd.md)).

## 12.8 Commands

| Command | Use |
|---|---|
| `python3 -m http.server 8001 --bind 127.0.0.1 --directory ~/lb/a` | throwaway backend on loopback |
| `sudo ln -s /etc/nginx/sites-available/X /etc/nginx/sites-enabled/` | enable a site (`rm` the link to disable) |
| `sudo nginx -t && sudo systemctl reload nginx` | test, then apply |
| `for i in 1 2 3 4 5 6; do curl -s localhost; done` | repeat a request (`-s` = no progress bar) |
| `1..4 \| % { curl.exe -s http://ubuntu-lab }` | same in PowerShell |
| `curl -i localhost` | show status line + headers too |
| `ps aux \| grep nginx` | master + workers (start time changes on reload) |
| `tail -n 20 /var/log/nginx/error.log` | why nginx failed (`upstream:` = which backend) |
| `tail -n 20 /var/log/nginx/access.log` | who the clients were |
| `sudo ss -tlnp \| grep 800` | which backends are listening, on which address |

## 12.9 Mistakes I made (Day 27)

| Wrote / thought | Problem | Fix |
|---|---|---|
| "a reverse proxy hides the backend's **content**" | the client gets the content; what's hidden is **where** the backend is | hides the backend's address and number |
| "loopback = LAN" | LAN is 192.168.x.x; loopback is the machine talking to itself | `lo` / 127.0.0.1 |
| guessed the backend sees `192.168.207.50` | connection 2 goes to `127.0.0.1` over `lo`, so its source is `127.0.0.1` | |
| backends got no requests after linking the site | no reload yet | `nginx -t` → `reload` |
| `grep "nginx: woker"` | typo → only the grep line itself | widen the search: `grep nginx` |
| 502 = "website not reachable" | too vague | 502 Bad Gateway: nginx alive, the backend failed |
| `Connection refused` = "unreachable" | different: refused = host answered, port has no listener; unreachable = no path | see [A.12 error words](appendix-a-troubleshooting.md#read-the-error-word-first) |
| "the log says refused, why check `ss`?" | the log is the past and doesn't say **why** nobody listens | `sudo ss -tlnp` before fixing |
