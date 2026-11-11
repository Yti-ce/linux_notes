# Chapter 1 — Environment and initial setup

Learned on **Day 1** (1.1–1.4: VM, install, network, SSH), **Day 4** (1.6: apt) and **Day 2** (1.7: paths); written up on Day 8. Shell commands used here are in [Chapter 0](00-shell-basics.md).

## 1.1 Create the VM

| Setting | Value | Why |
|---|---|---|
| Location | `E:\VMs\ubuntu-lab` | `C:` was nearly full; the first install failed because the disk could not grow |
| Guest OS | "Install the operating system later" | Skips VMware Easy Install so the installer can be run by hand |
| Resources | 2 vCPU, 4 GB RAM, 30 GB single-file disk | Enough for nginx, Docker later, and leaves RAM for the 16 GB host |
| Network | NAT (VMnet8) | Host can reach the VM directly by its IP, no port forwarding |

Attach the Ubuntu Server ISO and verify it first:

```powershell
Get-FileHash .\ubuntu-26.04.1-live-server-amd64.iso -Algorithm SHA256
# compare with SHA256SUMS on the official release page
```

## 1.2 Install Ubuntu Server

1. Default storage layout (LVM, ext4).
2. **Tick "Install OpenSSH server".** Without it there is no remote login.
3. If the installer hangs at "installing kernel", choose **Continue without network**, finish offline, and fix the network afterwards (1.3).

## 1.3 Network (DHCP)

```bash
sudo netplan set ethernets.ens33.dhcp4=true
sudo netplan apply
ip a show ens33          # look for: inet 192.168.207.x/24
ping -c 3 8.8.8.8        # internet reachable?
```

> ⚠️ The IP comes from DHCP and **can change after a reboot** (`.129` became `.130` on Day 9). The current IP is printed on the VM console login screen (`IPv4 address for ens33`), or run `ip a`. A static IP is set up in Chapter 9.

## 1.4 Log in over SSH

From Windows PowerShell:

```powershell
ssh admin123@192.168.207.130
```

Format: `ssh <user>@<ip>`, no space. Common mistakes:

| Typed | What happened |
|---|---|
| `ssh admin@123 192.168.207.255` | ssh read `123` as the host → `connect to host 0.0.0.123` |
| `...@192.168.207.255` | `.255` is the subnet **broadcast** address, not a machine |
| old IP after reboot | connection times out → check the IP on the VM console |

On the first connect, accept the host key fingerprint; it is saved in `~/.ssh/known_hosts`.

## 1.5 Hostname

```bash
hostname                              # show: admin (set in the installer)
sudo hostnamectl set-hostname <name>  # change it later if needed
```

The prompt `admin123@admin:~$` reads as **user**@**hostname**:**current directory**.

## 1.6 Packages with apt

```bash
sudo apt update                  # refresh the package index (always first)
apt show tree                    # read details before installing
sudo apt install -y tree         # -y = answer yes automatically
apt list --installed | grep openssh-server
sudo apt remove tree
```

`apt update` only downloads the list of available versions; `apt install` actually installs.

| Command | What it does |
|---|---|
| `apt search tree` | search package names and descriptions |
| `apt show tree` | version, `Installed-Size` (tree: 125 kB), description |
| `apt list --upgradable` | packages with a newer version |
| `sudo apt remove tree` | uninstall, **keep** config files |
| `sudo apt purge tree` | uninstall **and** delete config files |

- `install` / `remove` / `update` change the whole system → `sudo`. `show` / `search` / `list` only read → no `sudo`.
- Long output opens in the `less` pager: Space = next page, `q` = quit.
- Day 4 on this VM: mirror `my.archive.ubuntu.com`, release codename `resolute`.
- After `apt remove tree`, typing `tree` gave `/usr/bin/tree: No such file or directory` instead of "command not found": bash had cached the old path. Expected; `hash -r` clears the cache.

## 1.7 Absolute vs relative paths

| Path | Starts from | Example |
|---|---|---|
| Absolute | `/` (top of the disk) | `/usr/local/bin/timestamp.sh` |
| Relative | the current directory (`pwd`) | `quiz.txt` = `/home/admin123/quiz.txt` when in `~` |

Rule: **if the file is not in the current directory, write the full path starting with `/`.**

```text
admin123@admin:~$ sudo chmod 755 timestamp.sh
chmod: cannot access 'timestamp.sh': No such file or directory
admin123@admin:~$ sudo chmod 755 /usr/local/bin/timestamp.sh   # fixed
```

Not sure where you are? `pwd`.
