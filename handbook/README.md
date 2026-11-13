# Server Setup Handbook

A step-by-step handbook for building and running a small Ubuntu server, written while doing every step on my own lab VM. Phase 1 milestone of my 26-week Cloud / Linux / Networking plan.

**Goal:** someone (including me, later) can rebuild the same server from zero using only this handbook.

## Lab

| Item | Value |
|---|---|
| Hypervisor | VMware Workstation, NAT network (VMnet8) |
| Guest | Ubuntu Server 26.04.1 LTS, 2 vCPU, 4 GB RAM, 30 GB disk |
| Hostname / user | `admin` / `admin123` |
| Access | `ssh admin123@<vm-ip>` from Windows PowerShell |

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
| 7 | Scheduled jobs: `crontab`, environment in cron | Day 13 | ⏳ Day 13 |
| Appendix A | Troubleshooting record: 5 failure scenarios | Day 14 | ⏳ Day 14 |
| 8–12 | Networking, SSH hardening, firewall, nginx reverse proxy | Week 3–4 | ⏳ Week 3–4 |

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

Quick lookup of single commands: [cheatsheet.md](../cheatsheet.md).
