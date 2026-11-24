# Server Setup Handbook

A step-by-step handbook for building and running a small Ubuntu server, written while doing every step on my own lab VM. Phase 1 milestone of my 26-week Cloud / Linux / Networking plan.

**Goal:** someone (including me, later) can rebuild the same server from zero using only this handbook.

## Lab

| Item | Value |
|---|---|
| Hypervisor | VMware Workstation, NAT network (VMnet8) |
| Guest | Ubuntu Server 26.04.1 LTS, 2 vCPU, 4 GB RAM, 30 GB disk |
| Hostname / user | `admin` / `admin123` |
| Network | `ens33` NAT `192.168.207.50/24` (static, Day 22); `ens37` host-only `192.168.50.10/24` |
| Access | `ssh admin123@ubuntu-lab` (Windows hosts → .207.50) or `ssh admin123@192.168.50.10` |

## Contents

| Chapter | Topic | Learned on | Status |
|---|---|---|---|
| [0](00-shell-basics.md) | Shell basics: filesystem layout, files, viewing text, redirection and pipes, vim and nano | Day 2, 5, 6 | ✅ |
| [1](01-environment.md) | Environment and initial setup: VM, SSH, hostname, apt, paths | Day 1, 2, 4 | ✅ Day 8 |
| [2](02-permissions.md) | Users, groups and permissions: `useradd`, `chmod`, `chown`, `umask`, shared directory | Day 3, 7, 11 | ✅ rebuilt Day 11 |
| [3](03-processes.md) | Process management: `ps`, `top`, `kill`, signals, high-CPU triage | Day 8 | ✅ Day 8 |
| [4](04-systemd.md) | Service management with systemd: nginx, custom unit, boot test | Day 9 | ✅ Day 9 |
| [5](05-scripts.md) | Ops scripts: bash basics, backup, batch rename, disk alert ([`scripts/`](scripts/)) | Day 10 | ✅ Day 10 |
| [6](06-logs.md) | Logs and troubleshooting: `journalctl`, 3 failures on purpose, log analysis | Day 11–12 | ✅ Day 11–12 |
| [7](07-cron.md) | Scheduled jobs: `crontab`, time fields, PATH and `%` pitfalls | Day 13 | ✅ Day 13 |
| [A](appendix-a-troubleshooting.md) | Troubleshooting record: symptom → first command; 5 Linux failures (A.1–A.5), 4 network failures (A.7–A.10); Part 2: bottom-up network checklist (A.12), wrong gateway (A.13); 502 behind a reverse proxy (A.15) | Day 14, 25–27 | ✅ Day 14, 25–27 |
| [8](08-networking.md) | Networking basics: TCP/IP and OSI layers, tcpdump, Wireshark, MAC vs IP, TTL; IP and subnets (8.2); routing and NAT, Packet Tracer lab (8.3); DHCP and ARP (8.4); DNS (8.5); ports and connections (8.6); HTTP and HTTPS (8.7); VLANs and trunks (8.8) | Day 15–21, 25 | ✅ Day 15–21, 25 |
| [B](appendix-b-what-happens-url.md) | What happens when you type a URL: DNS → TCP → TLS → HTTP on one page | Day 21 | ✅ Day 21 |
| [9](09-network-config.md) | Network configuration: netplan static IP, host-only second NIC, routing table | Day 22 | ✅ Day 22 |
| [10](10-ssh-hardening.md) | SSH hardening: key login, `~/.ssh/config`, no password / root login, local port forwarding | Day 23 | ✅ Day 23 |
| [11](11-firewall.md) | Firewall: ufw allow 22/80/443, nmap from Windows, iptables rules behind ufw, blocking 80 and troubleshooting | Day 24 | ✅ Day 24 |
| [12](12-reverse-proxy.md) | nginx reverse proxy and load balancing: two Python backends, `upstream` round robin, `zone`, 502 drill ([`configs/nginx/lb-lab`](configs/nginx/lb-lab)) | Day 27 | ✅ Day 27 |

## Find by day

| Day | Topic | Where |
|---|---|---|
| 1 | Install Ubuntu Server, network, SSH | [1.1–1.4](01-environment.md#11-create-the-vm) |
| 2 | Filesystem layout, paths, file commands | [0.1–0.3](00-shell-basics.md#01-filesystem-layout-fhs--day-2), [1.7](01-environment.md#17-absolute-vs-relative-paths) |
| 3 | Users, groups, permissions | [Chapter 2](02-permissions.md) |
| 4 | Packages with apt | [1.6](01-environment.md#16-packages-with-apt) |
| 5 | Viewing text, redirection, pipes | [0.4–0.5](00-shell-basics.md#04-viewing-text--day-5) |
| 6 | vim and nano | [0.6](00-shell-basics.md#06-editing-files-vim-and-nano--day-6) |
| 7 | Week 1 quiz (17/20) | results in [README](../README.md#day-7--week-1-quiz); mistakes in [0.7](00-shell-basics.md#07-mistakes-i-made-days-27) and [2.8](02-permissions.md#28-mistakes-i-made-days-3-and-7) |
| 8 | Processes | [Chapter 3](03-processes.md) |
| 9 | systemd services | [Chapter 4](04-systemd.md) |
| 10 | Shell scripting, 3 ops scripts | [Chapter 5](05-scripts.md) |
| 11 | Permissions rebuild; `journalctl`, breaking and fixing nginx / timestamp | [2.9](02-permissions.md#29-rebuild-check-day-11), [6.1–6.5](06-logs.md) |
| 12 | grep / awk / sed, nginx access log analysis, `log_report.sh` | [6.6](06-logs.md#66-log-analysis-nginx-access-log-day-12) |
| 13 | cron: scheduled backup and disk check, breaking and fixing cron jobs | [Chapter 7](07-cron.md) |
| 14 | Week 2 quiz (6/20); 5 failure scenarios: config error, full disk, wrong group, port in use, cron | results in [README](../README.md#day-14--week-2-quiz-and-troubleshooting-drill); [Appendix A](appendix-a-troubleshooting.md) |
| 15 | TCP/IP and OSI layers; capture a ping with tcpdump, read it in Wireshark | [8.1](08-networking.md#81-layers-and-packet-capture) |
| 16 | IP addresses, prefix and mask, block-size method, 10 subnet questions | [8.2](08-networking.md#82-ip-addresses-and-subnets) |
| 17 | Routing table, default gateway, traceroute, NAT; two networks and a router in Packet Tracer | [8.3](08-networking.md#83-routing-and-nat) |
| 18 | ARP cache, DHCP (DORA, lease), router as DHCP server in Packet Tracer, running vs startup config | [8.4](08-networking.md#84-dhcp-and-arp) |
| 19 | DNS lookup chain, TTL, record types, `dig +trace` (and fixing it with `@8.8.8.8`), `/etc/hosts` | [8.5](08-networking.md#85-dns) |
| 20 | DNS review; Windows hosts → `ssh admin123@ubuntu-lab`; ports, `ss -tlnp`, TCP handshake and close, UDP | [8.5](08-networking.md#85-dns), [8.6](08-networking.md#86-ports-and-connections) |
| 21 | HTTP request/response, status codes, plain-text capture; self-signed cert, nginx on 443, `openssl s_client`, encrypted capture; one-page URL walk-through | [8.7](08-networking.md#87-http-and-https), [Appendix B](appendix-b-what-happens-url.md) |
| 22 | Day 21 review; netplan static IP `192.168.207.50`, `netplan try`, host-only NIC `ens37` `192.168.50.10`, two-NIC routing | [Chapter 9](09-network-config.md) |

| 23 | SSH keys (`ed25519`, `authorized_keys`, 700/600), `ssh lab` alias, `00-hardening.conf` (no passwords, no root), local port forward to nginx | [Chapter 10](10-ssh-hardening.md) |
| 24 | ufw default deny + allow 22/80/443, nmap `open`/`closed`/`filtered`, `iptables -L` (policy DROP, `dpt`), break 80 → inside-out troubleshooting → `[UFW BLOCK]` log | [Chapter 11](11-firewall.md) |
| 25 | Week 4 review: 4 drills broken by someone else — wrong IP in netplan, sshd typo (`Connection refused`), ufw rule order (first match wins), wrong Windows hosts entry; VLAN 10/20 and a trunk in Packet Tracer | [A.7–A.10](appendix-a-troubleshooting.md#a7-second-nic-unreachable-wrong-ip-in-netplan), [8.8](08-networking.md#88-vlans-and-trunks) |
| 26 | Network troubleshooting method: bottom-up checklist IP → gateway → outside IP → DNS → service, error words; drill: wrong gateway in netplan (`Destination Host Unreachable`) | [A.12–A.14](appendix-a-troubleshooting.md#part-2--network-troubleshooting-flow-day-26-2026-11-23) |
| 27 | Reverse proxy (two TCP connections, backend sees 127.0.0.1), round robin with `upstream`, per-worker counters and `zone`, client IP in access.log; drill: backends down → `502 Bad Gateway` → `error.log` → `ss` | [Chapter 12](12-reverse-proxy.md), [A.15](appendix-a-troubleshooting.md#a15-502-bad-gateway-backends-down) |

Quick lookup of single commands: [cheatsheet.md](../cheatsheet.md).
