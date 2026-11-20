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
| [A](appendix-a-troubleshooting.md) | Troubleshooting record: symptom → first command, 5 failure scenarios | Day 14 | ✅ Day 14 |
| [8](08-networking.md) | Networking basics: TCP/IP and OSI layers, tcpdump, Wireshark, MAC vs IP, TTL; IP and subnets (8.2); routing and NAT, Packet Tracer lab (8.3); DHCP and ARP (8.4); DNS (8.5); ports and connections (8.6); HTTP and HTTPS (8.7) | Day 15–21 | ✅ Day 15–21 |
| [B](appendix-b-what-happens-url.md) | What happens when you type a URL: DNS → TCP → TLS → HTTP on one page | Day 21 | ✅ Day 21 |
| [9](09-network-config.md) | Network configuration: netplan static IP, host-only second NIC, routing table | Day 22 | ✅ Day 22 |
| 10–12 | SSH hardening, firewall, nginx reverse proxy | Week 4 | ⏳ Week 4 |

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

Quick lookup of single commands: [cheatsheet.md](../cheatsheet.md).
