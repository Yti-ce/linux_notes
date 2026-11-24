# Appendix A — Troubleshooting record

Failures I caused on purpose and then fixed: five Linux ones on **Day 14** (2026-11-17, A.1–A.5) and four network ones on **Day 25** (2026-11-23, A.7–A.10). **Part 2** (Day 26) is the bottom-up network checklist (A.12) and a wrong-gateway drill (A.13); A.15 (Day 27) is a 502 behind the reverse proxy, with refused vs unreachable vs timeout. The chapters are organised by *what I learned*; this appendix is organised by *what broke*, so it is the place to start when something is wrong.

## A.0 Symptom → first command

| Symptom | First command | Then |
|---|---|---|
| website down / service won't start | `systemctl status <svc>` | `sudo journalctl -u <svc> -n 20 --no-pager` → read the `[emerg]` / error line ([A.1](#a1-nginx-will-not-start-config-error), [A.4](#a4-nginx-will-not-start-port-already-in-use)) |
| config error `in <file>:<line>` | `sudo nano <file>` (root-owned → `sudo`) | `sudo nginx -t` **before** restart |
| disk almost full | `df -h /` | `sudo du -sh /* 2>/dev/null \| sort -h`, go one level deeper each time; `sudo ls -lah <dir>` for hidden files ([A.2](#a2-disk-almost-full)) |
| `Permission denied` for a user | reproduce as that user: `sudo -u <user> touch <path>` | `ls -ld <dir>` (the directory itself), `id <user>` ([A.3](#a3-shared-directory-permission-denied)) |
| `Address already in use` | `sudo ss -tlnp \| grep :<port>` | `sudo kill <PID>`, start the service again |
| cron job does nothing | `sudo journalctl -u cron --since "10 min ago"` | run the script by hand **as the same user**, `ls -l` the script ([A.5](#a5-cron-job-never-produces-output)) |
| a NIC's IP doesn't answer, other NICs fine | `ip -br addr` | IP wrong → `/etc/netplan/*.yaml` → `sudo netplan try` ([A.7](#a7-second-nic-unreachable-wrong-ip-in-netplan)) |
| `Connection refused` | `sudo ss -tlnp \| grep ':<port> '` | nobody listening → `systemctl status` → `journalctl -u` / `sudo sshd -t` ([A.8](#a8-ssh-connection-refused-typo-in-sshd-config)) |
| timeout, service fine inside | `sudo ufw status numbered` | rule order, first match wins ([A.9](#a9-website-times-out-from-one-machine-ufw-rule-order)) |
| can't get out (apt, ping 8.8.8.8) | `ip route` → `ping -c 3 <gateway>` | `Destination Host Unreachable` from my own IP → wrong gateway in netplan ([A.13](#a13-apt-update-fails-wrong-gateway-in-netplan)); full flow in [A.12](#a12-bottom-up-checklist) |
| `502 Bad Gateway` from nginx | `tail -n 20 /var/log/nginx/error.log` | `upstream:` = which backend; `sudo ss -tlnp` on that port ([A.15](#a15-502-bad-gateway-backends-down)) |
| IP works, name doesn't | `ping -n 1 <name>` (shows the IP it resolved to) | hosts file, then DNS server ([A.10](#a10-name-doesnt-work-ip-does-wrong-hosts-entry)) |

General method (from [6.2](06-logs.md#62-method)): **reproduce → read status/logs → find the exact cause → fix one thing → verify, including that nothing else broke.**

## A.1 nginx will not start (config error)

**Break:**

```bash
echo "server { listen 8080 }" | sudo tee /etc/nginx/conf.d/test.conf > /dev/null
sudo systemctl restart nginx      # fails
```

**Diagnose:**

```console
admin123@admin:~$ sudo journalctl -u nginx -n 20 --no-pager
... nginx[18998]: [emerg] 18998#18998: unexpected "}" in /etc/nginx/conf.d/test.conf:1
```

`unexpected "}"` means the problem is just **before** the `}`: every nginx directive ends with `;`.

**Fix and verify:**

```console
admin123@admin:~$ sudo nano /etc/nginx/conf.d/test.conf     # server { listen 8080; }
admin123@admin:~$ sudo nginx -t
nginx: configuration file /etc/nginx/nginx.conf test is successful
admin123@admin:~$ sudo systemctl restart nginx
admin123@admin:~$ systemctl status nginx
     Active: active (running) since Tue 2026-11-17 06:42:39 UTC; 13s ago
admin123@admin:~$ curl localhost
<title>Welcome to nginx!</title> ...
```

Clean-up: `sudo rm /etc/nginx/conf.d/test.conf`, `sudo nginx -t && sudo systemctl reload nginx` (`&&` = run the second only if the first succeeded).

**Gap found:** the handbook never said that editing a root-owned config file needs `sudo nano` / `sudo vim`.

## A.2 Disk almost full

**Break** (fill the disk, leave 1 GB):

```bash
sudo fallocate -l $(( $(df --output=avail -B1 / | tail -n 1) - 1073741824 )) /var/tmp/.cache_data
```

**Diagnose:**

```console
admin123@admin:~$ df -h /
Filesystem                         Size  Used Avail Use% Mounted on
/dev/mapper/ubuntu--vg-ubuntu--lv   27G   25G  1.0G  97% /
admin123@admin:~$ ~/scripts/disk_alert.sh 80
Tue Nov 17 06:55:45 AM UTC 2026 ALERT: disk usage 97% is above 80%
admin123@admin:~$ sudo du -sh /* 2>/dev/null | sort -h
...
3.8G    /swap.img
18G     /var
admin123@admin:~$ sudo du -sh /var/* 2>/dev/null | sort -h
...
17G     /var/tmp
admin123@admin:~$ sudo du -sh /var/tmp/* 2>/dev/null | sort -h
8.0K    /var/tmp/systemd-private-...      # only a few KB — where are the 17 GB?
admin123@admin:~$ sudo ls -lah /var/tmp
total 17G
-rw-r--r--  1 root root  17G Nov 17 06:45 .cache_data
```

| Part | Meaning |
|---|---|
| `du -s` / `-h` | one total per argument / sizes in K, M, G |
| `2>/dev/null` | throw away `Permission denied` noise |
| `sort -h` | sort human sizes; biggest **last** |
| `/var/tmp/*` | `*` does **not** match names starting with `.` → hidden file missing |
| `ls -lah` | `-a` shows hidden files |

**Fix and verify:**

```console
admin123@admin:~$ sudo rm /var/tmp/.cache_data
admin123@admin:~$ df -h /
/dev/mapper/ubuntu--vg-ubuntu--lv   27G  7.2G   18G  29% /
```

In real life: find out **who created the file and whether something still uses it** before deleting.

**Gap found:** `du` was not in the handbook; `df -h /` was only inside the script section ([5.4](05-scripts.md#54-disk_alertsh-warn-when-the-disk-fills-up)).

## A.3 Shared directory: Permission denied

**Break:**

```bash
sudo chown root:root /srv/ops
```

**Diagnose:**

```console
admin123@admin:~$ sudo -u tom touch /srv/ops/tom.txt
touch: setting times of '/srv/ops/tom.txt': Permission denied
admin123@admin:~$ sudo ls -l /srv/ops            # lists what is INSIDE
-rw-r--r-- 1 tom tom 0 Nov 13 07:40 tom.txt
admin123@admin:~$ sudo ls -ld /srv/ops           # the directory ITSELF
drwxrwx--- 2 root root 4096 Nov 13 07:40 /srv/ops
admin123@admin:~$ id tom
uid=1005(tom) gid=1006(tom) groups=1006(tom),1009(ops)
```

`tom tom` = owner `tom`, group `tom`: `useradd` gives every user a **private group** with the same name. `ops` is the **team group**.

**Fix — two wrong tries first:**

| Tried | Result |
|---|---|
| `sudo chown :dev /srv/ops` | `dev` is the Day 3 group (alice, carol); tom is not in it |
| `sudo chown :tom /srv/ops` | tom can write, but **jerry is now locked out** |
| `sudo chown :ops /srv/ops` | ✅ |

```console
admin123@admin:~$ ls -ld /srv/ops
drwxrwx--- 2 root ops 4096 Nov 17 07:11 /srv/ops
admin123@admin:~$ sudo -u tom touch /srv/ops/tom3.txt
admin123@admin:~$ sudo -u jerry touch /srv/ops/jerry.txt
```

Lessons: shared directories belong to the **team** group; verify **every** user who should have access, not only the one who complained. Permission digits (`770`) were fine — only the group was wrong.

## A.4 nginx will not start (port already in use)

**Break:**

```bash
sudo systemctl stop nginx
sudo nohup python3 -m http.server 80 > /dev/null 2>&1 &
sudo systemctl start nginx         # fails
```

**Diagnose, fix, verify:**

```console
admin123@admin:~$ sudo journalctl -u nginx -n 20 --no-pager
... nginx: [emerg] bind() to 0.0.0.0:80 failed (98: Address already in use)   (5 retries)
... nginx: [emerg] still could not bind()
admin123@admin:~$ sudo ss -tlnp | grep :80
LISTEN 0  5  0.0.0.0:80  0.0.0.0:*  users:(("python3",pid=19871,fd=3))
admin123@admin:~$ sudo kill 19871
[1]+  Terminated   sudo nohup python3 -m http.server 80 > /dev/null 2>&1
admin123@admin:~$ sudo systemctl start nginx
admin123@admin:~$ systemctl status nginx
     Active: active (running) since Tue 2026-11-17 07:18:21 UTC; 9s ago
admin123@admin:~$ curl localhost         # skipped on Day 14 — status "running" ≠ site works, always curl
```

`ss -tlnp`: **t** TCP, **l** listening, **n** numeric ports, **p** process (needs `sudo`).

## A.5 cron job never produces output

**Break:**

```bash
printf '#!/bin/bash\ndate >> /home/admin123/hello.log\n' > ~/scripts/hello.sh
chmod -x ~/scripts/hello.sh
(crontab -l; echo "* * * * * /home/admin123/scripts/hello.sh") | crontab -
```

Symptom: `~/hello.log` never appears.

**Diagnose:**

```console
admin123@admin:~$ sudo journalctl -u cron --since "10 min ago"
... CRON[20103]: (admin123) CMD (/home/admin123/scripts/hello.sh)
... CRON[20101]: (CRON) info (No MTA installed, discarding output)
admin123@admin:~$ sudo ~/scripts/hello.sh       # should have been without sudo, see below
sudo: cannot execute '/home/admin123/scripts/hello.sh': Permission denied (os error 13)
admin123@admin:~$ echo $?
1
admin123@admin:~$ ls -l ~/scripts/hello.sh
-rw-r--r-- 1 admin123 admin123 45 Nov 17 07:19 /home/admin123/scripts/hello.sh
```

- `CMD (...)` → cron **does** run it every minute; cron is fine.
- `No MTA installed, discarding output` → the script failed; cron tried to e-mail the error, there is no mail system, so the error was thrown away. The line has no `>> log 2>&1`, so nothing was kept.
- Reproduce **as the same user cron uses** (admin123), not with `sudo`.

**Fix and verify:**

```console
admin123@admin:~$ chmod +x ~/scripts/hello.sh         # my own file → no sudo
admin123@admin:~$ cat ~/hello.log
Tue Nov 17 07:34:01 AM UTC 2026
Tue Nov 17 07:35:01 AM UTC 2026
```

Clean-up: `crontab -e`, delete the `hello.sh` line, `crontab -l` shows only the two real jobs.

Lesson: every cron line gets `>> /home/admin123/cron.log 2>&1`, or its errors are lost (see [7.3](07-cron.md#73-my-jobs)).

## A.6 Mistakes I made (Day 14)

| Typed | Problem | Fix |
|---|---|---|
| `ls -l /srv/ops` to see the directory's owner | lists the contents | `ls -ld /srv/ops` |
| `chown :dev`, then `chown :tom` | wrong group, then the user's private group | team group `:ops`; check with `id <user>` |
| `sudo ~/scripts/hello.sh` to reproduce a cron failure | cron runs as admin123, not root | run it without `sudo` |
| stopped at `status: running` | process alive ≠ site reachable | `curl localhost` |

## Day 25 drills (2026-11-23)

Someone else breaks it; I only see the symptom. Same skeleton every time: **narrow it down → check layer by layer from the bottom → find who configured it → check before applying → verify from the other side.**

The symptom → first command rows are in [A.0](#a0-symptom--first-command).

## A.7 Second NIC unreachable (wrong IP in netplan)

**Break:** `sudo sed -i 's#192.168.50.10/24#192.168.5.10/24#' /etc/netplan/00-installer-config.yaml && sudo netplan apply` (only ens37 changes, so ssh over ens33 survives).

**Symptom:** `ping 192.168.50.10` from Windows times out; `ssh lab` (ens33) still fine → the problem is on **ens37 only**.

**Diagnose:**

```console
admin123@admin:~$ ip -br addr
ens37            UP             192.168.5.10/24 ...      ← link is UP, but the IP is wrong
```

`192.168.5.10` is not in Windows' VMnet1 network `192.168.50.0/24`, so nothing answers.

**Fix and verify:** `sudo nano /etc/netplan/00-installer-config.yaml` → `192.168.50.10/24` → `sudo netplan try` (Enter) → `ip -br addr` shows `.50.10` → ping from Windows works.

**Why the first ping timed out after the fix:** Windows first needs the VM's **MAC** (ARP request "who has 192.168.50.10?" → reply). The first packet waits for that; the rest use the ARP cache (`arp -a` on Windows). IP decides who it's for, MAC decides who gets it on this hop.

## A.8 ssh: Connection refused (typo in sshd config)

Rule: **keep the old ssh window open** the whole time; it is the lifeline (or use the VMware console).

**Break:** `echo 'PasswordAuthenticaton no' | sudo tee -a /etc/ssh/sshd_config.d/00-hardening.conf && sudo systemctl restart ssh`

**Symptom:** a new window: `ssh: connect to host 192.168.207.50 port 22: Connection refused` (key and password both).

**Diagnose:**

| Step | Command | Saw | Tells me |
|---|---|---|---|
| read the error word | `ssh lab` | `Connection refused` | packet arrived, **nobody listening** — not the firewall (that would be a timeout) |
| port | `sudo ss -tlnp \| grep ':22 '` | empty | sshd not listening |
| service | `sudo systemctl status ssh` | `failed` | it failed to start |
| why | `sudo journalctl -u ssh -n 20 --no-pager` | `00-hardening.conf: line 3: Bad configuration option: PasswordAuthenticaton` | file + line |

The last lines of a log are the conclusion (`Failed to start`); **the reason is a few lines above.**

**Fix and verify:** fix the spelling (or delete line 3: line 1 already says `PasswordAuthentication no`, and sshd uses the **first** value it sees) → `sudo systemctl restart ssh` → `sudo sshd -t` (no output = OK) → `sudo ss -tlnp | grep ':22 '` → `ssh lab` in a **new** window.

`sudo sshd -t` while the service is down may say `Missing privilege separation directory: /run/sshd`: `/run` lives in memory and systemd creates `/run/sshd` only when the service starts. A side effect of the service being down, not a config error.

**Why the old window never dropped:** `sshd -D [listener]` is the front desk that accepts new logins; each logged-in user gets their own `sshd-session` process. Restarting ssh kills only the front desk. Safe way to change sshd: **`sshd -t` → restart → test in a new window → only then close the old one.**

## A.9 Website times out from one machine (ufw rule order)

**Break:** `sudo ufw insert 1 deny from 192.168.207.1 to any port 80 proto tcp` (207.1 = Windows on VMnet8).

(First try was `sudo ufw insert 1 deny 80/tcp` → `Skipping inserting existing rule`: ufw compares only the **conditions** (port, protocol, source), not the action, so it keeps one rule per condition. `sudo ufw deny 80/tcp` would have turned the ALLOW into DENY: `Rule updated`.)

**Diagnose:** service → port → inside → firewall:

```console
admin123@admin:~$ sudo ss -tlnp | grep ':80 '
LISTEN 0 511 0.0.0.0:80 ... users:(("nginx",pid=1214,...))      ← listening (grep :80 alone also matches 8080)
admin123@admin:~$ sudo systemctl status nginx
     Active: active (running)                                      ← service fine
admin123@admin:~$ sudo ufw status numbered
[ 1] 80/tcp                     DENY IN     192.168.207.1          ← above the ALLOW
[ 4] 80/tcp                     ALLOW IN    Anywhere
```

**First match wins:** rules are checked top to bottom and the first one that matches decides. Packets from 207.1 hit [1] and are dropped; [4] is never reached. So specific rules go on top (`insert 1`), general ones below; a plain `ufw deny` is appended at the end and would never win against an earlier allow.

**Fix and verify:** `sudo ufw delete 1` (read the numbers first: a wrong number could delete 22) → `curl.exe -m 5 http://192.168.207.50` from Windows.

## A.10 Name doesn't work, IP does (wrong hosts entry)

**Break (Windows, admin PowerShell):** back up `hosts` to `$HOME\hosts.bak`, then change `192.168.207.50 ubuntu-lab` to `.51`.

**Symptom:** `curl.exe -m 5 http://192.168.207.50` works, `curl.exe -m 5 http://ubuntu-lab` doesn't → network, firewall and nginx are fine → **name resolution**.

**Diagnose:**

```powershell
PS> ping ubuntu-lab
正在 Ping ubuntu-lab [192.168.207.51] ...      ← resolved to the wrong IP; nothing lives on .51
```

Windows looks a name up in: **DNS cache → hosts file → DNS server.** Wrong answer → check hosts first (people edit it by hand), then the DNS server. `nslookup` asks the DNS server directly and **skips hosts**, so it can disagree with `ping`.

**Fix and verify:** admin PowerShell → `notepad C:\Windows\System32\drivers\etc\hosts` → `.50` → save (`ipconfig /flushdns` if ping still shows `.51`) → `ping ubuntu-lab` shows `[192.168.207.50]`, `curl.exe http://ubuntu-lab` shows the nginx page.

| Linux | Windows |
|---|---|
| `sudo nano /etc/hosts` | admin PowerShell, `notepad C:\Windows\System32\drivers\etc\hosts` |

## A.11 Mistakes I made (Day 25)

| Typed | Problem | Fix |
|---|---|---|
| forgot `ip -br addr` | the first check for any NIC/IP problem | `ip -br addr` (name / state / IP per line) |
| `ss -tlnp \| grep 22` | no `sudo` → no process column; `22` also matches `2222` | `sudo ss -tlnp \| grep ':22 '` |
| `curl.exe -m http://...` | `-m` needs seconds | `curl.exe -m 5 http://...` |
| `ufw status nembered` | typo | `numbered` |

---

# Part 2 — Network troubleshooting flow (Day 26, 2026-11-23)

## A.12 Bottom-up checklist

**Why bottom-up:** upper layers depend on lower ones. No IP → no gateway → no DNS → no website, so an error at the top can be caused at the bottom. Each step checks **one** thing; the **first step that fails** is where to look.

> Interview line: *"I go bottom-up so each check rules out one layer, and the first failure tells me where to look."*

| # | Question | Command | Good result (my VM) | If it fails |
|---|---|---|---|---|
| 1 | Does the NIC have an IP? | `ip -br addr` | `ens33 UP 192.168.207.50/24` | link `DOWN` / wrong or no IP → netplan ([A.7](#a7-second-nic-unreachable-wrong-ip-in-netplan)) |
| 2 | Is a gateway **configured**, and does it **answer**? | `ip route` then `ping -c 3 192.168.207.2` | `default via 192.168.207.2 dev ens33`, 0% loss | no `default` line, or the gateway doesn't answer ([A.13](#a13-apt-update-fails-wrong-gateway-in-netplan)) |
| 3 | Can I reach an outside **IP**? | `ping -c 3 8.8.8.8` | 0% loss | path/routing problem. An IP on purpose: this rules DNS out |
| 4 | Do **names** resolve? | `dig google.com +short`, then `dig @8.8.8.8 google.com +short`; which server: `resolvectl status` | IPs printed; `DNS Servers: 192.168.207.2` | normal fails but `@8.8.8.8` works → **my configured DNS server** is broken/wrong → netplan `nameservers` |
| 5 | Does the **service** answer? | client: `curl.exe -I http://192.168.207.50`; server: `sudo ss -tlnp \| grep ':80 '`, `systemctl status nginx` | `HTTP/1.1 200 OK` | `refused` → nobody listening ([A.8](#a8-ssh-connection-refused-typo-in-sshd-config)); timeout → firewall ([A.9](#a9-website-times-out-from-one-machine-ufw-rule-order)) |

"Step 4" here is a step in my list, **not OSI layer 4**: DNS is an application-layer (L7) protocol.

### Read the error word first

| Error | Meaning | Usual cause |
|---|---|---|
| `connect: Network is unreachable` | my machine has no route at all; nothing is sent | no `default` route |
| `From <my own IP> ... Destination Host Unreachable` | I know where to send it, but nobody on my subnet answers ARP for the target/gateway; nothing leaves the machine | gateway IP wrong, host off |
| no replies, `100% packet loss` (timeout) | packets left, nothing came back | firewall drops, broken path |
| `Connection refused` | packet arrived, nobody listening on that port | service down |
| `Temporary failure in name resolution` | the name couldn't be turned into an IP | DNS |
| `Permission denied` | not a network problem at all | forgot `sudo` |

### Check before applying, per tool

| Tool | Check | Apply |
|---|---|---|
| nginx | `sudo nginx -t` | `sudo systemctl reload nginx` |
| sshd | `sudo sshd -t` | `sudo systemctl restart ssh` |
| netplan (a tool, **not a service**) | `sudo netplan try` (auto-reverts after 120 s unless Enter) | Enter to accept |

## A.13 apt update fails (wrong gateway in netplan)

**Break:** `sudo sed -i 's/via: 192\.168\.207\.2$/via: 192.168.207.99/' /etc/netplan/00-installer-config.yaml && sudo netplan apply` (only the route changes, so ssh over ens33 survives; `.99` is an unused address on VMnet8).

**Symptom:** "`sudo apt update` suddenly doesn't work."

**Diagnose (logic chain):**

| Question | Command | Saw | Rules out / tells me |
|---|---|---|---|
| Is a gateway configured? | `ip route` | `default via 192.168.207.99` | a default route exists, but `.99` is not what VMware NAT uses |
| Does that gateway exist? | `ping -c 3 192.168.207.99` | `From 192.168.207.50 ... Destination Host Unreachable` ×3 | my own machine reports it: ARP "who has .99?" got no answer → **no such host** on the subnet |
| Who configured it? | `find /etc -name "*.yaml" 2>/dev/null` → `sudo cat /etc/netplan/00-installer-config.yaml` | `routes: - to: default  via: 192.168.207.99` | the cause, in a file |

I spotted `.99` at once only because I remembered `.2`. On someone else's machine I won't know the right answer, so the ping is the **evidence** that the gateway is wrong.

**Fix and verify:** `sudo nano /etc/netplan/00-installer-config.yaml` → `via: 192.168.207.2` → `sudo netplan try` → Enter → bottom-up again: `ip route` (`via 192.168.207.2`) → `ping -c 3 192.168.207.2` → `ping -c 3 8.8.8.8` → back to the **original symptom**: `sudo apt update` → `Hit:` / `Get:` lines, `Fetched 1,079 kB in 2s`.

DNS (`192.168.207.2`) is on my own subnet, so with a wrong gateway names still resolve; only traffic that has to leave the subnet fails.

## A.14 Mistakes I made (Day 26)

| Typed | Problem | Fix |
|---|---|---|
| `find /etc ".conf" 2>/dev/null` (warm-up, question asked for `.yaml`) | no `-name`, so find treats `".conf"` as another path; no `*`; didn't read the question | `find /etc -name "*.yaml" 2>/dev/null` |
| `find /etc -name "*.netplan"` | `-name` matches the **file name**; `netplan` is the directory, the files end in `.yaml` | `find /etc -name "*.yaml"` or `ls /etc/netplan/` |
| step 3 = `resolvectl status` | that's DNS (step 4); step 3 tests an outside IP | `ping -c 3 8.8.8.8` |
| step 2 = only `ip route` | shows the gateway is configured, not that it answers | also `ping -c 3 <gateway>` |
| only `dig @8.8.8.8 ...` | no comparison | `dig name` first, then `dig @8.8.8.8 name` |
| `ping -c 8.8.8.8` | `-c` needs a count | `ping -c 3 8.8.8.8` |
| `apt update` | `Permission denied (13)`: apt writes to root-owned dirs | `sudo apt update` |

## A.15 502 Bad Gateway (backends down)

*Day 27 (2026-11-24).* Setup and full logic chain in [12.6](12-reverse-proxy.md#126-drill-backends-die-502-bad-gateway).

**Break:** nginx proxies to two backends (`127.0.0.1:8001`, `:8002`); stop both (`Ctrl+C`). With only one stopped, clients see nothing: nginx retries the other one.

**Chain:** `curl -i localhost` → `502 Bad Gateway` (nginx answered, so the problem is behind it) → `systemctl status nginx` `active` → `error.log`: `connect() failed (111: Connection refused) while connecting to upstream ... upstream: "http://127.0.0.1:8001/"` → `sudo ss -tlnp | grep 800` empty → backends not running → start them → `ss` shows both → curl A/B again.

### refused vs unreachable vs timeout

| Error | What happened | Layer / where to look | Speed | Seen in |
|---|---|---|---|---|
| `Network is unreachable` | no route; nothing was sent | my routing table: `ip route` | instant | — |
| `Destination Host Unreachable` | nobody answered ARP for that IP | network: IP / gateway / host off | seconds | [A.13](#a13-apt-update-fails-wrong-gateway-in-netplan) |
| timeout / 100% loss | sent, nothing came back | something drops packets: firewall | slow | [11](11-firewall.md), [A.9](#a9-website-times-out-from-one-machine-ufw-rule-order) |
| `Connection refused` | host alive and answered (TCP RST), **no program on that port** | the service: `ss -tlnp`, `systemctl status` | instant | [A.8](#a8-ssh-connection-refused-typo-in-sshd-config), A.15 |

`unreachable` = can't find the **machine**; `refused` = found the machine, not the **program**; timeout = someone **drops** silently. `ping` has no ports, so it can never say `refused`.

