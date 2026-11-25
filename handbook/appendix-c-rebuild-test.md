# Appendix C — Rebuild test: a new server from this handbook only

*Day 28 (2026-11-25), Phase 1 milestone.* The goal of the handbook is that someone can build the same server from zero using only these pages. So I built a **second VM** and allowed myself nothing but the handbook. Every place where I got stuck or the handbook was silent was fixed on the spot (list at the end).

## The second server

| Item | `ubuntu-lab` (Days 1–27) | `rebuild` (Day 28) |
|---|---|---|
| VM folder | `E:\VMs\ubuntu-lab` | `E:\VMs` → should be its own folder (see C.3) |
| Hostname | `admin` | `rebuild` |
| Static IP | `192.168.207.50/24` | `192.168.207.60/24` (must differ: both VMs share VMnet8) |
| Windows hosts name | `ubuntu-lab` | `rebuild-lab` |
| ssh alias (`~/.ssh/config`) | `lab` | `rebuild` |
| Same private key | ✅ `id_ed25519` | ✅ only the public key was copied, no new key pair |

Not rebuilt (not part of the milestone): second NIC `ens37`, users/groups lab, scripts, cron, reverse proxy.

## C.1 The 11 steps

| # | Step | Handbook | Check | Result |
|---|---|---|---|---|
| 1 | Create VM, attach ISO, install, reboot, console login | [1.1–1.2](01-environment.md#11-create-the-vm) | prompt `admin123@rebuild:~$` | ✅ after 2 fixes (ISO, mirror) |
| 2 | Update packages | [1.6](01-environment.md#16-packages-with-apt) | `sudo apt update` | ✅ |
| 3 | First ssh from Windows (DHCP `.132`) | [1.4](01-environment.md#14-log-in-over-ssh) | password login works | ✅ |
| 4 | Static IP `.60` with `netplan try` **at the console** | [9.1–9.3](09-network-config.md#93-static-ip-on-ens33) | `ip -br addr`, `ping 8.8.8.8`, still `.60` after reboot | ✅ |
| 5 | Windows hosts `192.168.207.60 rebuild-lab` | [8.5](08-networking.md#85-dns) | `ping rebuild-lab` | ✅ |
| 6 | Copy the existing public key | [10.2](10-ssh-hardening.md#102-make-a-key-and-put-it-on-the-server) | `ssh admin123@rebuild-lab` asks no password | ✅ (after running it from Windows, not from inside the VM) |
| 7 | `Host rebuild` alias | [10.3](10-ssh-hardening.md#103-client-alias-sshconfig) | `ssh rebuild` | ✅ |
| 8 | `00-hardening.conf`: no passwords, no root | [10.4–10.5](10-ssh-hardening.md#104-turn-off-password-and-root-login) | `Permission denied (publickey)` without key | ✅ |
| 9 | nginx on 80, self-signed HTTPS on 443 | [4.2](04-systemd.md#42-nginx), [8.7](08-networking.md#87-http-and-https) | `curl.exe -I http://rebuild-lab`, `curl.exe -kI https://rebuild-lab` → 200 | ✅ |
| 10 | ufw: 22 first, then 80/443, enable | [11.4](11-firewall.md#114-rules-then-enable) | `nmap -p 22,80,443 192.168.207.60` → all `open` | ✅ |
| 11 | Reboot, check everything again from Windows | — | see C.2 | ✅ |

Extra after the rebuild: How-To-Secure comparison ([10.8](10-ssh-hardening.md#108-compared-with-how-to-secure-a-linux-server-day-28), [11.9](11-firewall.md#119-rate-limit-ssh-compared-with-how-to-secure-a-linux-server-day-28)) and a DNS drill on this server ([A.16](appendix-a-troubleshooting.md#a16-names-dont-resolve-local-dns-resolver-stopped)).

## C.2 Final check after reboot (all from Windows)

```powershell
PS> ssh rebuild "ip -br addr; systemctl is-active nginx ssh"
lo               UNKNOWN        127.0.0.1/8 ::1/128
ens33            UP             192.168.207.60/24 fe80::20c:29ff:fea6:73ca/64
active
active
PS> ssh -t rebuild "sudo ufw status"          # -t: sudo needs a terminal to ask for the password
Status: active
PS> curl.exe -I http://rebuild-lab
HTTP/1.1 200 OK
Server: nginx/1.28.3 (Ubuntu)
PS> curl.exe -kI https://rebuild-lab
HTTP/1.1 200 OK
```

## C.3 Where the handbook failed me, and the fix

| # | What happened | Cause | Fixed in |
|---|---|---|---|
| 1 | First boot: `PXE-M0F: Exiting Intel PXE ROM` / `Operating System not found` | "Install the OS later" leaves the CD empty; the handbook said "attach the ISO" but not how | [1.1](01-environment.md#11-create-the-vm): VM → Settings → CD/DVD → ISO, *Connect at power on* |
| 2 | ISO no longer on disk | deleted after Day 1 | re-downloaded from `releases.ubuntu.com/26.04/`, checked SHA256 against `SHA256SUMS` |
| 3 | VM files landed directly in `E:\VMs` | typed the parent folder in the wizard | [1.1](01-environment.md#11-create-the-vm): give each VM its own folder |
| 4 | Installer mirror: `my.archive.ubuntu.com:80 ... Connection refused` | that mirror had nothing on port 80 (DNS and network were fine) | [1.2](01-environment.md#12-install-ubuntu-server): use `http://archive.ubuntu.com/ubuntu/` or skip and `apt update` later |
| 5 | Same IP / hostname as the first VM would clash | handbook assumed one VM | [1.2](01-environment.md#12-install-ubuntu-server): own hostname, `.60`, own hosts name |
| 6 | `ssh` to the new server asked for a password | I ran it **inside the VM** (prompt `admin123@rebuild`), where there is no private key | [10.2](10-ssh-hardening.md#102-make-a-key-and-put-it-on-the-server): check the prompt first |
| 7 | `hp@rebuild-lab: Permission denied (publickey)` | used the hosts name, not the ssh alias; no `User`, so ssh sent my Windows user name | [10.3](10-ssh-hardening.md#103-client-alias-sshconfig): hosts name ≠ ssh alias |
| 8 | `curl -I` in PowerShell asked for `Uri:` | PowerShell's `curl` is `Invoke-WebRequest` | [11.10](11-firewall.md#1110-commands): use `curl.exe` |
| 9 | `ssh rebuild "sudo ufw status"` → `sudo: A terminal is required` | no terminal for the password prompt | `ssh -t` ([10.9](10-ssh-hardening.md#109-commands)) |
| 10 | Expected 443 `closed`, got `open` | I had also built the HTTPS site; allowed + listening = open | [11.9](11-firewall.md#119-rate-limit-ssh-compared-with-how-to-secure-a-linux-server-day-28): table of open / closed / filtered |

The known_hosts message on the first connection (`Permanently added 'rebuild-lab'`) looked like an error but is normal — now explained in [10.2](10-ssh-hardening.md#102-make-a-key-and-put-it-on-the-server). A handy one-liner for the hosts file (admin PowerShell):

```powershell
Add-Content C:\Windows\System32\drivers\etc\hosts "`r`n192.168.207.60   rebuild-lab"
```

## C.4 Verdict

The handbook was enough to rebuild the server in about 1.5 hours (VM install included). The gaps were all at the **edges** — the VMware wizard, the installer, and Windows-side commands — not in the Linux chapters themselves. Those edges are now written down.
