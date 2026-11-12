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

## Key concepts learned

- **Kernel vs. distribution vs. shell**: the kernel manages hardware; a distribution packages the kernel with tools and a package manager (`apt` on Ubuntu); the shell (`bash`) interprets commands.
- **LVM**: adds a logical-volume layer so filesystems can be resized later.
- **DHCP on NAT**: VMware runs a small DHCP server and NAT service on the host for VMnet8.
- **BIOS boot order**: disk → CD → network (PXE). If all fail you get "Operating System not found".
- **SSH host keys**: protect against man-in-the-middle attacks; a changed fingerprint triggers a warning.
