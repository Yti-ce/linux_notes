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

| Chapter | Topic | Status |
|---|---|---|
| [1](01-environment.md) | Environment and initial setup: VM, SSH, hostname, apt, paths | ✅ Day 8 |
| 2 | Users, groups and permissions | ⏳ Day 10 |
| [3](03-processes.md) | Process management: `ps`, `top`, `kill`, signals, high-CPU triage | ✅ Day 8 |
| [4](04-systemd.md) | Service management with systemd: nginx, custom unit, boot test | ✅ Day 9 |
| 5 | Ops scripts: backup, batch rename, disk alert (`scripts/`) | ⏳ Day 10 |
| 6 | Logs and troubleshooting: `journalctl`, `/var/log`, log analysis | ⏳ Day 11–12 |
| 7 | Scheduled jobs: `crontab`, environment in cron | ⏳ Day 13 |
| Appendix A | Troubleshooting record: 5 failure scenarios | ⏳ Day 14 |
| 8–12 | Networking, SSH hardening, firewall, nginx reverse proxy | ⏳ Week 3–4 |
