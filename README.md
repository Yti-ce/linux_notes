# linux_notes

Notes and labs from my 26-week Cloud / Linux / Networking plan (target: IT internship in Kuala Lumpur).

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

## Day 2 — Filesystem hierarchy and paths

Practiced FHS directories, absolute vs. relative paths, and `ls/cd/mkdir/touch/cp/mv/rm/find` in a sandbox directory `~/lab`. Command reference: [cheatsheet.md](cheatsheet.md).

## Day 3 — Users, groups and permissions

Created users `alice`, `bob`, `carol` and group `dev`, built a shared directory `/srv/dev` (`root:dev`, `770`) and verified access as each user. Covered `chmod` (symbolic and numeric), `chown`, `useradd`, `groupadd`, `usermod -aG`, `umask`. Lab record: [permissions-lab.md](permissions-lab.md).

## Day 4 — Package management with apt

Refreshed the index (`apt update`, mirror `my.archive.ubuntu.com`, release codename `resolute`), inspected `tree` with `apt show` (125 kB), installed it, used it on `/srv` and removed it. `tree /srv` as `admin123` showed `dev [error opening dir]` because `/srv/dev` is `root:dev 770` and `admin123` falls under *others*; `sudo tree /srv` listed `alice.txt`. Confirmed `openssh-server` is installed with `apt list --installed`. Commands: [cheatsheet.md](cheatsheet.md#package-management-with-apt-day-4).

## Day 5 — Viewing text, redirection and pipes

Used `cat/head/tail/less` on `/etc/passwd` and `/var/log/syslog`, wrote files with `>` (overwrite) and `>>` (append), and chained commands with `|`, `grep`, `grep -v`, `wc -l` and `sort`. Completed 15 pipe exercises, e.g. counting login users (`grep bash /etc/passwd | wc -l` → 5) and cron runs in syslog. Commands: [cheatsheet.md](cheatsheet.md#viewing-text-redirection-and-pipes-day-5).

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
| Boot showed `PXE-E53` / "Operating System not found" | Disk had no completed install, and the installer had ejected the virtual CD | Reconnected the CD/DVD in VMware and reset the VM |

## Key concepts learned

- **Kernel vs. distribution vs. shell**: the kernel manages hardware; a distribution packages the kernel with tools and a package manager (`apt` on Ubuntu); the shell (`bash`) interprets commands.
- **LVM**: adds a logical-volume layer so filesystems can be resized later.
- **DHCP on NAT**: VMware runs a small DHCP server and NAT service on the host for VMnet8.
- **BIOS boot order**: disk → CD → network (PXE). If all fail you get "Operating System not found".
- **SSH host keys**: protect against man-in-the-middle attacks; a changed fingerprint triggers a warning.
