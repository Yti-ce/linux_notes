# linux_notes

Notes and labs from my 26-week Cloud / Linux / Networking plan (target: IT internship in Kuala Lumpur).

> **How this repo was made:** notes drafted with an AI tutor; all labs run and verified by me on my own VM. The terminal output, mistakes and troubleshooting entries are from my own sessions.

## Lab environment

| Item | Value |
|---|---|
| Host | Windows, 16 GB RAM |
| Hypervisor | VMware Workstation Pro 17 |
| Guest OS | Ubuntu Server 26.04.1 LTS (kernel 7.0) |
| VM resources | 2 vCPU, 4 GB RAM, 30 GB disk (LVM, ext4) |
| Network | NAT (VMnet8), DHCP via netplan |
| Access | SSH from Windows Terminal |

## Day 1 — Install Ubuntu Server and connect over SSH

1. Created a VM with "install the OS later" (skips VMware Easy Install), then attached the ISO.
2. Verified the ISO with SHA256 against the official `SHA256SUMS`.
3. Installed Ubuntu Server manually: default LVM layout, **OpenSSH server** enabled, no snaps.
4. Enabled DHCP on the NIC and applied it:
   ```bash
   sudo netplan set ethernets.ens33.dhcp4=true
   sudo netplan apply
   ip a show ens33
   ping -c 3 8.8.8.8
   ```
5. Connected from Windows:
   ```powershell
   ssh <user>@<vm-ip>
   ```
   Accepted the host key fingerprint on first connect (stored in `~/.ssh/known_hosts`).

Handbook: [Chapter 1](handbook/01-environment.md).

## Day 2 — Filesystem hierarchy and paths

Practiced FHS directories, absolute vs. relative paths, and `ls/cd/mkdir/touch/cp/mv/rm/find` in a sandbox directory `~/lab`. Command reference: [cheatsheet.md](cheatsheet.md). Handbook: [0.1–0.3](handbook/00-shell-basics.md), [1.7](handbook/01-environment.md#17-absolute-vs-relative-paths).

## Day 3 — Users, groups and permissions

Created users `alice`, `bob`, `carol` and group `dev`, built a shared directory `/srv/dev` (`root:dev`, `770`) and verified access as each user. Covered `chmod` (symbolic and numeric), `chown`, `useradd`, `groupadd`, `usermod -aG`, `umask`. Lab record: [permissions-lab.md](permissions-lab.md). Handbook: [Chapter 2](handbook/02-permissions.md).

## Day 4 — Package management with apt

Refreshed the index (`apt update`, mirror `my.archive.ubuntu.com`, release codename `resolute`), inspected `tree` with `apt show` (125 kB), installed it, used it on `/srv` and removed it. `tree /srv` as `admin123` showed `dev [error opening dir]` because `/srv/dev` is `root:dev 770` and `admin123` falls under *others*; `sudo tree /srv` listed `alice.txt`. Confirmed `openssh-server` is installed with `apt list --installed`. Commands: [cheatsheet.md](cheatsheet.md#package-management-with-apt-day-4). Handbook: [1.6](handbook/01-environment.md#16-packages-with-apt).

## Day 5 — Viewing text, redirection and pipes

Used `cat/head/tail/less` on `/etc/passwd` and `/var/log/syslog`, wrote files with `>` (overwrite) and `>>` (append), and chained commands with `|`, `grep`, `grep -v`, `wc -l` and `sort`. Completed 15 pipe exercises, e.g. counting login users (`grep bash /etc/passwd | wc -l` → 5) and cron runs in syslog. Commands: [cheatsheet.md](cheatsheet.md#viewing-text-redirection-and-pipes-day-5). Handbook: [0.4–0.5](handbook/00-shell-basics.md#04-viewing-text--day-5).

## Day 6 — vim and nano

Learned vim's Normal vs Insert mode (`i`/`A`/`o` to type, `Esc` to stop), `x`, `dd`, `:wq`, `:q!`, and finished vimtutor Lesson 1. Edited a real config file, `~/.vimrc` (`set number`, `set mouse=`). Saved and exited a file in nano (`Ctrl+O`, `Ctrl+X`). Commands: [cheatsheet.md](cheatsheet.md#editing-files-vim-and-nano-day-6). Handbook: [0.6](handbook/00-shell-basics.md#06-editing-files-vim-and-nano--day-6).

## Day 7 — Week 1 quiz

20 hands-on questions on the VM, closed book, in 4 rounds: files and paths, users and permissions, apt and pipes, vim. **17/20 correct**, but 11 needed a look at the cheat sheet.

| Round | Result | Missed or looked up |
|---|---|---|
| Files and paths | 4/5 | `ls -l /quiz` instead of `~/quiz` (absolute vs relative); looked up `mkdir`, `mv` |
| Users and permissions | 3/5 | `chmod 620` instead of `640` (group read = 4, not 2); could not recall `chown`; looked up `id`, `useradd -m` |
| apt, redirection, pipes | 5/5 | looked up `apt update`, `apt install`, `>`/`>>`, `head -n`; did not know how to use `tree` |
| vim | 5/5 | nothing (`o`, `Esc`, `dd`, `:wq`, `:q!`) |

Milestone "basic admin tasks on my own": **mostly met**. vim and pipes are solid; permissions are the weak spot, so I rewrote them in depth: [permissions-guide.md](permissions-guide.md). Weak items are marked ⚠️ in [cheatsheet.md](cheatsheet.md).

## Day 8 — Processes

Warm-up (closed book): `chmod 640` ✅, `chown root:root` needed a reminder, `head -n 3` ✅. Listed processes with `ps` and `ps aux | grep`, created a high-CPU process with `yes > /dev/null &`, found it with `top` (99.7% = one of two cores) and `ps aux | grep`, and stopped it with `kill` (SIGTERM → `Terminated`) and `kill -9` (SIGKILL → `Killed`). Handbook: [Chapter 1](handbook/01-environment.md), [Chapter 3](handbook/03-processes.md).

## Day 9 — systemd

Installed nginx and saw that `start`/`stop` (now) and `enable`/`disable` (at boot) are independent. Wrote a custom service (`timestamp.sh` + `timestamp.service`) that logs the time every minute; its first start hit `start-limit-hit` because of a typo (`ture`), found by reading `status` and the script. Rebooted: nginx and the custom service both came back on their own. Handbook: [Chapter 4](handbook/04-systemd.md).

## Day 10 — Shell scripting

Learned exit codes (`$?`, 0 = success, 127 = command not found), variables, arguments (`$1`, `$#`), `$(...)`, `[ ]` tests, `if`/`else`, `for` and functions. Built three scripts step by step: [`backup.sh`](handbook/scripts/backup.sh), [`rename.sh`](handbook/scripts/rename.sh), [`disk_alert.sh`](handbook/scripts/disk_alert.sh). Testing found real bugs: a backup script that printed "created" and returned 0 when tar had failed, a `[ -d"$1" ]` test that was always true, and `"dir"` without `$`. Handbook: [Chapter 5](handbook/05-scripts.md).

## Day 11 — Logs and troubleshooting

Warm-up: could not write `ls -l /srv` (absolute path) or change only a file's group (`sudo chown :adm f`); `chmod 640` right. Rebuilt the Chapter 2 permissions lab from scratch with new names (`tom`, `jerry`, `eve`, group `ops`, `/srv/ops` 770): all checks passed ([2.9](handbook/02-permissions.md#29-rebuild-check-day-11)). Then `journalctl` (`-u`, `-n`, `-b`, `--since/--until`, `--no-pager`) and three failures caused on purpose and fixed from the logs: nginx config syntax error, port 80 already in use (`ss -tlnp`, `kill`), and a missing execute bit on the custom service (`203/EXEC`). Also traced a real nginx restart to a system update. Handbook: [Chapter 6](handbook/06-logs.md).

## Day 12 — Text processing and log analysis

Warm-up: absolute path and pipe right; used `head` where `tail` was asked. Generated 159 requests with `curl` in a `for` loop (plus browser refreshes from Windows), read the access log field by field, and counted status codes and top IPs with `awk | sort | uniq -c | sort -rn | head`; `sed 's/old/new/'` for replacing text. Wrapped it in [`log_report.sh`](handbook/scripts/log_report.sh) with a missing-file check. Handbook: [6.6](handbook/06-logs.md#66-log-analysis-nginx-access-log-day-12).

## Day 13 — Scheduled jobs with cron

First pass on 11-13, redone from scratch on 11-16. Warm-up: `head` for "last lines" again, `--since` missing its `--`; `chown admin123 f` right. Found the backup test job still running every 2 minutes (108 archives), fixed it to `0 2 * * *` and cleaned up with `ls` before `rm`. Added timestamps to `disk_alert.sh` output, compared terminal and cron PATH (same on this Ubuntu, via `/etc/environment`), and broke cron twice on purpose: a bare script name (`not found`) and an unescaped `%` (command cut short, output discarded; found in `journalctl -u cron`). Handbook: [Chapter 7](handbook/07-cron.md).

## Day 14 — Week 2 quiz and troubleshooting drill

**Quiz: 6/20** (closed book, 4 rounds of 5).

| Round | Result | Missed |
|---|---|---|
| Processes and systemd | 1/5 | `systemctl` verb order and `enable` vs `enabled`; `ss -tlnp`; `journalctl -u`; `daemon-reload` after editing a unit file |
| Shell scripts | 2/5 | `#!` written as `!#`; `( )` instead of `[ ]` in `if`; `$0` / `$?`; `chmod +x` without a file name |
| Text processing | 1/5 | `cat` instead of `tail -f`; `awk '{print $1}'`; `uniq -c` vs `wc -l`; `sed 's/foo/bar/g'` |
| cron and permissions | 2/5 | `journalctl -u cron`; ⭐ `chown :ops` written as `chmod` (5th time) |

Week 1 was 17/20, week 2 is 6/20: services, logs and text tools need repetition, not new material. Weak spots are marked ⭐ in [cheatsheet.md](cheatsheet.md) and go into the daily warm-up.

Then five failures caused on purpose and fixed from the handbook only: nginx config error, disk filled to 97%, shared directory with the wrong group, port 80 taken by another program, cron job whose script lost `x`. All five fixed; the three ⭐ commands were each used correctly at least once. Gaps found in the handbook (`du`, hidden files, `sudo nano` for root-owned configs) are now covered. Handbook: [Appendix A](handbook/appendix-a-troubleshooting.md).

## Day 15 — Network layers and packet capture

Warm-up (closed book): `tail -n 5` ✅; ⭐ `ss -tlnp` right but `grep : 22` (stray space); ⭐ `daemon-reload` remembered but given a service name and no `sudo` on restart. Learned the TCP/IP and OSI models, captured a ping with `tcpdump` (8 packets, saved as `ping.pcap`), copied it to Windows with `scp` and marked the link, network and ICMP layers in Wireshark. Found that the destination MAC is the NAT gateway's (`ip route`, `ip neigh`), not Google's, and that the reply's TTL of 128 points to VMware NAT on the Windows host. Handbook: [8.1](handbook/08-networking.md#81-layers-and-packet-capture).

## Day 16 — IP addresses and subnets

Warm-up: ⭐ `chown :dev /srv/dev` right (second time in a row); `df -h /` right but `du` without `sort -h`; `unique` for `uniq`. Learned IPv4 structure, CIDR prefix vs subnet mask, network and broadcast addresses, and the block-size method. Worked out my VM's network (`192.168.207.0/24`, broadcast `.255`, 254 hosts) and matched it with `ip addr` (`brd`) and `ip route`. **10/10** on the closed-book subnet questions after four mistakes while learning (2⁷, wrong block size, range start, misread prefix). Handbook: [8.2](handbook/08-networking.md#82-ip-addresses-and-subnets).

## Day 17 — Routing, gateways and NAT

Warm-up: ⭐ `sudo ss -tlnp | grep :80` right (first time closed book); `journalctl -u nginx -n 20 --no-pager` right; /24 answered as 255 addresses / 253 usable (it is 256 / 254). Read the VM's routing table (`ip route`, `ip route get`), traced the path to 8.8.8.8 (first hop = VMware NAT gateway `.2`), and found the two NATs between the VM and the internet (`curl ifconfig.me`, `ipconfig`). Found a second, hand-added default route on Windows (VMnet1, metric 291) that loses to Wi-Fi (metric 200). Built two networks and one router in Packet Tracer: `ping` across with TTL 127, `tracert` shows the gateway first, and removing PC0's gateway breaks only cross-network traffic. Handbook: [8.3](handbook/08-networking.md#83-routing-and-nat).

## Day 18 — DHCP and ARP, week review

Warm-up: ⭐ `daemon-reload` remembered but spelt `deamon`; ⭐ `chown :ops /srv/ops` right for the third time but without `sudo`; skipped the gateway question. Read the VM's ARP cache (`ip neigh`: `.1` Windows, `.2` gateway, `.254` DHCP server, matched by MAC) and its DHCP lease (`networkctl status`, `journalctl -u systemd-networkd`), including two `lease lost` → `acquired` cycles that gave back the same `.130`. In Packet Tracer, made the router a DHCP server (PC0 got `.10`, the first address after the excluded `.1–.9`) and watched Discover → Offer → Request → Ack in Simulation mode. Lost the router config with Power Cycle and learned `copy running-config startup-config`. Handbook: [8.4](handbook/08-networking.md#84-dhcp-and-arp).

**Week review (Days 15–18).** Most useful: starting to use the network for real (ICMP, Wireshark, DHCP, routing) instead of only learning commands. Still weak: commands I recognise when I see them but can't write from memory, so the warm-up now also picks one command not tested for a while. Pace stays the same: one new idea at a time, then hands-on in the VM or Packet Tracer.

## Day 19 — DNS

Warm-up (new format: weak point + recent mistakes + older commands): ⭐ `daemon-reload` spelt right; `/27` question all right; `/25` right but 125 usable instead of 126; `find` by name and `tar -czf` not known (now on the weak-points list); `chmod 750` right. Followed a lookup from the VM: `127.0.0.53` (systemd-resolved) → `192.168.207.2` (VMware NAT, also the DNS server from DHCP) → upstream. Watched a TTL count down, queried A / AAAA / MX / CNAME / NS records, and walked root → .com → ns2.google.com with `dig +trace`. `+trace` first timed out because the local forwarders don't answer `. NS`; asking `@8.8.8.8` proved the network was fine. Added a name to `/etc/hosts` and saw that the local stub reads it but an outside DNS server does not. Handbook: [8.5](handbook/08-networking.md#85-dns).

## Day 20 — Ports and TCP connections

Warm-up 3/5: ⭐ `ss -tlnp` right, /25 = 128/126 right, `chmod 750` right; `find` (wrote `/etc/*.conf &2>`) and `tar -czf` still wrong. Reviewed Day 19 DNS by answering questions: forwarder vs recursive resolver vs authoritative, root → .com → authoritative, A vs NS, why `+trace` fails at `. NS`, one server asked per level. Finished the Windows hosts lab (`ssh admin123@ubuntu-lab`). Read `ss -tlnp` (`0.0.0.0` vs `127.0.0.53%lo`), captured a full HTTP connection (handshake → data → close) and a 2-packet UDP DNS query; saw the client's ephemeral port change every time. Handbook: [8.6](handbook/08-networking.md#86-ports-and-connections).

## Day 21 — HTTP and HTTPS

Read a full request/response with `curl -v`, a 404, and the matching `access.log` lines. Captured a password in plain HTTP with `tcpdump -A`. Made a self-signed certificate, served nginx on 443, saw curl refuse it (`SEC_E_UNTRUSTED_ROOT`) and accept it with `-k`; compared my cert with google.com's using `openssl s_client` (subject = issuer → self-signed vs a CA chain). Captured HTTPS: password gone, site name still visible in the ClientHello (SNI). Milestone: one-page "what happens when you type a URL". Handbook: [8.7](handbook/08-networking.md#87-http-and-https), [Appendix B](handbook/appendix-b-what-happens-url.md).

## Day 22 — Network configuration

Warm-up 3/5: ⭐ `daemon-reload` right, `tar -czf` right for the first time, cron line right; `find -name /*.conf` (extra `/`) and nginx access records looked up with `journalctl` instead of `access.log`. Reviewed Day 21 by filling in the "type a URL" chain (4/6, then fixed), private vs public key, what HTTPS hides. Took a snapshot, set a static IP `192.168.207.50` with netplan (lost ssh once by running `netplan try` over ssh; redid it in the console), updated the Windows hosts entry, then gave the host-only NIC `ens37` `192.168.50.10` and reached the VM from Windows over both networks. Handbook: [Chapter 9](handbook/09-network-config.md).

## Day 23 — SSH hardening

Warm-up 1.5/5: ⭐ `ss -tlnp | grep :22` right; `find -name *.conf` without quotes; `scp`, `sed 's///g'` and finding a PID with `ps aux | grep` not known (these three now go into every warm-up). Made an `ed25519` key on Windows, put the public key into `authorized_keys` (700/600 — nobody else may add a key), added a `ssh lab` alias, then turned off password and root login with my own `sshd_config.d/00-hardening.conf` (cloud-init's `50-` file said `PasswordAuthentication yes` and would have won over the main file). Verified from a new window: key in, password and root refused with `Permission denied (publickey)`. Reached nginx through `ssh -L 8080:localhost:80 lab`; access.log showed `127.0.0.1` (loopback). Handbook: [Chapter 10](handbook/10-ssh-hardening.md).

## Server Setup Handbook

Phase 1 milestone, written chapter by chapter: [handbook/](handbook/README.md). Every topic from Day 1 on has a chapter; the handbook's "Find by day" table maps each day to its section.

How the files fit together:

| File | Use it for |
|---|---|
| [handbook/](handbook/README.md) | step-by-step setup, organised by topic (the milestone) |
| [cheatsheet.md](cheatsheet.md) | one-line lookup of a command |
| [permissions-guide.md](permissions-guide.md) | permissions explained in depth (Chinese) |
| [permissions-lab.md](permissions-lab.md) | Day 3 raw lab record |
| this README | daily log, quiz results, troubleshooting log |

## Troubleshooting log

| Symptom | Root cause | Fix |
|---|---|---|
| Installer failed at "installing kernel" (1st attempt) | Host `C:` drive nearly full; VM disk and `.vmem` file could not grow | Rebuilt the VM on `E:` |
| `ens33` showed "autoconfiguration failed" | VMware NAT/DHCP service on the host not serving DHCP | Checked VMware DHCP/NAT services and VMnet8 settings |
| Installer failed again at "installing kernel" | Guest network unreliable during install, so package download failed | Installed **offline** (network disabled), configured networking afterwards with netplan |
| `tree /srv` → `dev [error opening dir]` | `/srv/dev` is `770`; `admin123` is not owner or in group `dev` | Expected; use `sudo` or add user to `dev` |
| After `apt remove tree`, `tree` → `/usr/bin/tree: No such file or directory` | bash cached the old command path | Expected; `hash -r` clears the cache |
| `touch -n 3 /var/log/syslog` → `unexpected argument '-n'` | Typed `touch` instead of `tail` | Check the command name first when an option is rejected |
| `echo /etc/passwd \| grep bash > f` gave an empty file | `echo` prints the text "/etc/passwd", not the file | Use `cat /etc/passwd \| grep bash` |
| vim showed `-- VISUAL --` unexpectedly | Mouse click inside vim (mouse support on by default) | `Esc`; added `set mouse=` to `~/.vimrc` |
| File got an extra `i` line in vim | Pressed `i` while already in Insert mode | `Esc` to Normal mode, `dd` on that line, `:wq` |
| Stray empty file `/quiz` owned by root | Ran `sudo touch /quiz` meaning `~/quiz`; leading `/` = top of the disk, and `sudo` let it write there | `sudo rm /quiz`; read the path before any `sudo` command |
| Boot showed `PXE-E53` / "Operating System not found" | Disk had no completed install, and the installer had ejected the virtual CD | Reconnected the CD/DVD in VMware and reset the VM |
| `ssh admin@123 192.168.207.255` → `connect to host 0.0.0.123` | `@` belongs to the user name (`admin123`); `.255` is the broadcast address | `ssh admin123@<vm-ip>`, no space |
| `touch quiz..txt` created a second file | Typo (two dots) | Read the command before Enter; `rm quiz..txt` |
| `sudo chmod 755 timestamp.sh` → `No such file or directory` | Relative path from `~`; the file is in `/usr/local/bin` | Use the absolute path |
| Custom service `failed (Result: start-limit-hit)`, `status=0/SUCCESS` after 24 ms | `while ture` typo: the loop never ran, script exited at once, `Restart=always` retried 5× | Fixed to `true`, `systemctl restart` |
| SSH timed out after `sudo reboot` | DHCP gave the VM a new IP (`.129` → `.130`) | Read the IP on the VM console login screen; static IP in Chapter 9 |
| `dir=cat /var/log` → `/var/log: Is a directory`, `$dir` empty | A space ends the value; bash ran `/var/log` as a command | `dir=/var/log`; check with `echo "$dir"` |
| `checkdir.sh /nothing` said "is a directory" | `[ -d"$1" ]`: missing space, so `[ ]` only tested "non-empty" | `[ -d "$1" ]` |
| `backup.sh` with no argument printed "Backup created", exit 0 | No input check; `$?` came from the final `echo` | `-z` / `! -d` guards with `exit 1` |
| `rename.sh` said an existing directory "is not a directory" | `[ ! -d "dir" ]`: missing `$` | `"$dir"`; always test the success case |
| `~/scirpts/disk_alert.sh` → exit 127 | Typo in the path | 127 = command not found: check spelling |
| `chmod 770 /srv/ops` → `Operation not permitted` | After `chown root:ops` I was no longer the owner | `sudo chmod` |
| `sudo systemctl restart nginx` → `Job for nginx.service failed` | Missing `;` in `sites-available/default` (on purpose) | `journalctl -u nginx` → `[emerg] ... :23`; fix, `sudo nginx -t`, restart |
| nginx `bind() to 0.0.0.0:80 failed (98: Address already in use)` | Another program (python3) held port 80 (on purpose) | `sudo ss -tlnp \| grep :80`, `sudo kill <PID>`, start nginx |
| `timestamp.service` `status=203/EXEC`, `Permission denied` | Script lost its `x` bit (on purpose) | `sudo chmod 755 /usr/local/bin/timestamp.sh` |
| `journalctl -u /usr/local/bin/timestamp.sh` → `-- No entries --` | `-u` takes the service name | `journalctl -u timestamp` |
| `log_report.sh: line 4: wc-l: command not found` | Missing space | `wc -l` |
| 32 × 404 and only 102 × 200 instead of 31 / 101+ | Browser also asked for `/favicon.ico`; refreshes returned `304` | Expected; read the log, not the guess |
| `/bin/sh: 1: /home/admin123/scripts/bcakup.sh: not found` in cron.log | Typo in the crontab line | `backup.sh` |
| 108 backup archives after 3 days | `*/2` test schedule never switched to daily | `0 2 * * *`; `ls` the pattern, then `rm` |
| cron job `echo "$(date +%F) test"` wrote nothing at all | `%` = newline in crontab: command cut, redirection lost, output discarded (no MTA) | `\%`, or keep `%` inside scripts |
| nginx `unexpected "}" in /etc/nginx/conf.d/test.conf:1` | Missing `;` after `listen 8080` (on purpose) | `sudo nano` the file, `sudo nginx -t`, restart |
| Disk 97% full | 17 GB hidden file `/var/tmp/.cache_data` (on purpose); `du dir/*` skipped it | `du -sh` level by level, `ls -lah`, `rm` |
| tom: `Permission denied` in `/srv/ops` | Directory group changed to `root` (on purpose); first fixes used `dev`, then tom's private group | `sudo chown :ops /srv/ops`, test tom **and** jerry |
| cron job never wrote `hello.log` | Script had no `x` bit; error discarded (`No MTA installed`) | `chmod +x`; add `>> log 2>&1` to every cron line |

## Key concepts learned

- **Kernel vs. distribution vs. shell**: the kernel manages hardware; a distribution packages the kernel with tools and a package manager (`apt` on Ubuntu); the shell (`bash`) interprets commands.
- **LVM**: adds a logical-volume layer so filesystems can be resized later.
- **DHCP on NAT**: VMware runs a small DHCP server and NAT service on the host for VMnet8.
- **BIOS boot order**: disk → CD → network (PXE). If all fail you get "Operating System not found".
- **SSH host keys**: protect against man-in-the-middle attacks; a changed fingerprint triggers a warning.
