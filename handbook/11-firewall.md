# 11. Firewall with ufw

*Day 24 (2026-11-21).* Chapter 10 locked the SSH door. But every program that listens on `0.0.0.0` is an open door to the network. A firewall is the guard at the entrance: **incoming traffic is refused unless the port is on the list; outgoing traffic is allowed.** This chapter allows only 22/80/443, proves it from Windows with nmap, looks at the iptables rules ufw writes, then breaks port 80 on purpose and troubleshoots it.

**Before you start:**
1. Take a VMware snapshot (`before-ufw`).
2. **Allow 22 before `ufw enable`.** Enabling without it cuts ssh immediately. If that happens, log in at the VMware console (it doesn't go through the network) and run `sudo ufw allow 22/tcp`.

## 11.1 ufw and iptables

```
ufw allow 80/tcp  →  ufw (simple front end)  →  iptables / nftables rules  →  Linux kernel drops or accepts each packet
```

The kernel does the filtering. iptables rules are long and easy to get wrong; **ufw** ("Uncomplicated Firewall", installed on Ubuntu) writes them for you.

## 11.2 What is open now

```console
admin123@admin:~$ sudo ufw status verbose
Status: inactive
admin123@admin:~$ sudo ss -tlnp
Local Address:Port      Process
0.0.0.0:8080            nginx            ← Day 20 test site, reachable from outside
127.0.0.53%lo:53        systemd-resolve  ← loopback only
127.0.0.54:53           systemd-resolve  ← loopback only
0.0.0.0:443             nginx
0.0.0.0:80              nginx
0.0.0.0:22              sshd
```

The column to read is **Local Address**:

| Port | Service | Bound to | Reachable from outside? |
|---|---|---|---|
| 22 | SSH (sshd) | `0.0.0.0` | yes — needed |
| 80 | HTTP (nginx) | `0.0.0.0` | yes — needed |
| 443 | HTTPS (nginx, Day 21 cert) | `0.0.0.0` | yes — needed |
| 8080 | HTTP test site (nginx, Day 20) | `0.0.0.0` | yes — **not needed** |
| 53 | DNS (systemd-resolved) | `127.0.0.53` / `.54` on `lo` | no — VM only |

## 11.3 Scan from outside before (nmap on Windows)

nmap has to run **outside** the VM: the firewall filters traffic coming in, so scanning yourself from inside shows nothing. Prompt check: `PS C:\Users\HP>` = Windows, `admin123@admin:~$` = VM.

```powershell
PS> winget install -e --id Insecure.Nmap      # accept the Npcap installer; open a new PowerShell after
PS> nmap -p 22,80,443,8080 192.168.207.50
PORT     STATE SERVICE
22/tcp   open  ssh
80/tcp   open  http
443/tcp  open  https
8080/tcp open  http-proxy
```

(The garbled text after the time is the Windows time-zone name in the wrong encoding — ignore it.)

## 11.4 Rules, then enable

Rules first — while ufw is inactive, a mistake costs nothing:

```console
admin123@admin:~$ sudo ufw default deny incoming
admin123@admin:~$ sudo ufw default allow outgoing
admin123@admin:~$ sudo ufw allow 22/tcp
admin123@admin:~$ sudo ufw allow 80/tcp
admin123@admin:~$ sudo ufw allow 443/tcp
admin123@admin:~$ sudo ufw enable
Command may disrupt existing ssh connections. Proceed with operation (y|n)? y
admin123@admin:~$ sudo ufw status verbose
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), disabled (routed)

To                         Action      From
22/tcp                     ALLOW IN    Anywhere
80/tcp                     ALLOW IN    Anywhere
443/tcp                    ALLOW IN    Anywhere
22/tcp (v6)                ALLOW IN    Anywhere (v6)      ← IPv6 copies added automatically
...
```

The ssh session did not drop → 22 is allowed. `ufw enable` survives reboots.

## 11.5 Scan again

```powershell
PS> nmap -p 22,80,443,8080 192.168.207.50
PORT     STATE    SERVICE
22/tcp   open     ssh
80/tcp   open     http
443/tcp  open     https
8080/tcp filtered http-proxy     ← nginx still listens; the firewall drops the packets
```

| nmap state | What came back | Meaning |
|---|---|---|
| `open` | SYN-ACK | a program accepted the connection |
| `closed` | RST ("nobody here") | host answered, no program on that port, no firewall in the way |
| `filtered` | **nothing** | a firewall dropped the packet silently (ufw's default) |

I guessed `closed`; it was `filtered` because ufw **drops** instead of answering.

## 11.6 The iptables rules behind ufw

```console
admin123@admin:~$ sudo iptables -L INPUT -n | head -8
Chain INPUT (policy DROP)
target     prot opt source               destination
ufw-before-logging-input  all  --  0.0.0.0/0            0.0.0.0/0
ufw-before-input  all  --  0.0.0.0/0            0.0.0.0/0
ufw-after-input  all  --  0.0.0.0/0            0.0.0.0/0
ufw-after-logging-input  all  --  0.0.0.0/0            0.0.0.0/0
ufw-reject-input  all  --  0.0.0.0/0            0.0.0.0/0
ufw-track-input  all  --  0.0.0.0/0            0.0.0.0/0
admin123@admin:~$ sudo iptables -L ufw-user-input -n
Chain ufw-user-input (1 references)
target     prot opt source               destination
ACCEPT     tcp  --  0.0.0.0/0            0.0.0.0/0            tcp dpt:22
ACCEPT     tcp  --  0.0.0.0/0            0.0.0.0/0            tcp dpt:80
ACCEPT     tcp  --  0.0.0.0/0            0.0.0.0/0            tcp dpt:443
```

How a packet is checked:
1. **INPUT** is the chain for packets coming in. Rules are checked **top to bottom**; the `ufw-*` lines jump into ufw's own chains, and my allow rules live in `ufw-user-input`.
2. The **first matching rule decides** (a packet to port 22 → `ACCEPT`).
3. If **nothing matches** (port 8080), the chain's **policy** applies: `DROP` = discard silently. That line is `ufw default deny incoming`.

| Field | Meaning |
|---|---|
| `target` | what to do: `ACCEPT`, `DROP`, or jump to another chain |
| `prot` | protocol (`tcp`, `udp`, `all`) |
| `source` / `destination` | addresses; `0.0.0.0/0` = any |
| `dpt:22` | **d**estination **p**or**t** 22 (`spt` = source port) |
| `-L` / `-n` | list rules / show numbers, don't look up names |

## 11.7 Break port 80 on purpose, then troubleshoot

**Break:**

```console
admin123@admin:~$ sudo ufw delete allow 80/tcp          # removes both the IPv4 and v6 rule
```

**Symptom** ("the website is down"):

```powershell
PS> curl.exe -m 5 http://ubuntu-lab                     # -m 5 = give up after 5 s → timeout
```

**Troubleshoot from the inside out** — service → port → from inside → firewall:

```console
admin123@admin:~$ sudo systemctl status nginx
     Active: active (running) since Fri 2026-11-20 15:20:04 UTC; 21h ago      ← 1. service is up
admin123@admin:~$ sudo ss -tlnp | grep :80
LISTEN 0 511 0.0.0.0:80 ... nginx                                              ← 2. listening on all NICs
admin123@admin:~$ curl -I http://localhost
HTTP/1.1 200 OK                                                                ← 3. works from inside
admin123@admin:~$ sudo ufw status verbose
22/tcp   ALLOW IN   Anywhere
443/tcp  ALLOW IN   Anywhere                                                   ← 4. no 80 → the firewall
```

Step 3 is the key split: **works inside, fails outside → the problem is on the path in**, and the firewall is the first suspect.

**Proof** — ufw logs what it drops to the kernel log:

```console
admin123@admin:~$ sudo journalctl -k --since "15 min ago" | grep "UFW BLOCK" | grep "DPT=80 " | tail -3
Nov 21 13:11:34 admin kernel: [UFW BLOCK] IN=ens33 OUT= MAC=... SRC=192.168.207.1 DST=192.168.207.50 LEN=52 ... TTL=128 ... PROTO=TCP SPT=27097 DPT=80 ... SYN URGP=0
Nov 21 13:11:35 admin kernel: [UFW BLOCK] ... SRC=192.168.207.1 ... SPT=27097 DPT=80 ... SYN
Nov 21 13:11:37 admin kernel: [UFW BLOCK] ... SRC=192.168.207.1 ... SPT=27097 DPT=80 ... SYN
```

| Field | Here | Meaning |
|---|---|---|
| `IN=ens33` | NAT NIC | where it arrived |
| `SRC` | `192.168.207.1` | **Windows** (its VMnet8 address) |
| `DST` / `DPT` | `.50` / `80` | the VM's port 80 |
| `SPT` | `27097` | Windows' ephemeral port (Day 20) |
| `SYN` | | first packet of the handshake — dropped before any connection |
| `TTL` | `128` | hops left; Windows starts at 128, Linux at 64; no router in between so still 128 |

Same `SPT` at :34, :35, :37: the VM never answered, so Windows **retransmitted the SYN** after 1 s, then 2 s — that waiting is what `filtered` / a timeout looks like.

(IP **TTL** = hops left. **DNS TTL** (Day 19) = seconds a record may be cached. Same abbreviation, different things.)

**Fix and verify:**

```console
admin123@admin:~$ sudo ufw allow 80/tcp
```

```powershell
PS> curl.exe -m 5 http://ubuntu-lab
<title>Welcome to nginx!</title>        ← back
```

## 11.8 Firewall checklist

- [x] Snapshot before changes
- [x] `default deny incoming`, `default allow outgoing`
- [x] Allowed `22/tcp` **before** `ufw enable`; ssh session stayed up
- [x] Allowed only `80/tcp`, `443/tcp` besides 22
- [x] nmap from Windows: 22/80/443 `open`, 8080 `filtered`
- [x] Logging on; know how to read `[UFW BLOCK]` lines
- [ ] Later: remove the unused 8080 site from nginx instead of only hiding it (Chapter 12 reorganises nginx)

## 11.9 Commands

| Command | Use |
|---|---|
| `sudo ufw status verbose` | on/off, default policy, rules |
| `sudo ufw default deny incoming` / `allow outgoing` | default policy |
| `sudo ufw allow 22/tcp` | allow a port (**22 first**) |
| `sudo ufw enable` / `disable` | turn on / off |
| `sudo ufw delete allow 80/tcp` | remove a rule (or `ufw status numbered` + `ufw delete N`) |
| `nmap -p 22,80,443,8080 IP` | scan from **outside**; `open` / `closed` / `filtered` |
| `sudo iptables -L INPUT -n` | the real rules; `policy` = what happens when nothing matches |
| `sudo iptables -L ufw-user-input -n` | my ufw rules as iptables |
| `curl -I http://localhost` | test from inside: inside OK + outside fails → path / firewall |
| `sudo journalctl -k \| grep "UFW BLOCK"` | dropped packets (SRC, DPT, SYN) |

## 11.10 Mistakes I made (Day 24)

| Wrote | Problem | Fix |
|---|---|---|
| `winget install ...` at `admin123@admin:~$` | that's the VM; winget is a Windows tool | `exit` (or a new PowerShell), check for `PS C:\Users\HP>` |
| `Insecure.Namp` | typo | `Nmap` (network mapper); copy instead of typing |
| guessed 8080 would be `closed` after ufw | ufw drops silently, so no RST comes back | `filtered` |
| (asked) is TTL a time? | name says time, IP uses it as a hop counter | IP TTL = hops left; DNS TTL = seconds cached |
