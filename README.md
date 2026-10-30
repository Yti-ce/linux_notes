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

## Troubleshooting log

| Symptom | Root cause | Fix |
|---|---|---|
| Installer failed at "installing kernel" (1st attempt) | Host `C:` drive nearly full; VM disk and `.vmem` file could not grow | Rebuilt the VM on `E:` |
| `ens33` showed "autoconfiguration failed" | VMware NAT/DHCP service on the host not serving DHCP | Checked VMware DHCP/NAT services and VMnet8 settings |
| Installer failed again at "installing kernel" | Guest network unreliable during install, so package download failed | Installed **offline** (network disabled), configured networking afterwards with netplan |
| Boot showed `PXE-E53` / "Operating System not found" | Disk had no completed install, and the installer had ejected the virtual CD | Reconnected the CD/DVD in VMware and reset the VM |

## Key concepts learned

- **Kernel vs. distribution vs. shell**: the kernel manages hardware; a distribution packages the kernel with tools and a package manager (`apt` on Ubuntu); the shell (`bash`) interprets commands.
- **LVM**: adds a logical-volume layer so filesystems can be resized later.
- **DHCP on NAT**: VMware runs a small DHCP server and NAT service on the host for VMnet8.
- **BIOS boot order**: disk → CD → network (PXE). If all fail you get "Operating System not found".
- **SSH host keys**: protect against man-in-the-middle attacks; a changed fingerprint triggers a warning.
