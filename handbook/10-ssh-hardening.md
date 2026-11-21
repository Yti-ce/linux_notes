# 10. SSH hardening: key login, no passwords, no root

*Day 23 (2026-11-21).* Until now I logged in with `ssh admin123@ubuntu-lab` and a password. Anyone who guesses or steals that password gets in, and bots on the internet try exactly that on port 22 all day. This chapter switches the server to **key-only login**, turns off root login, adds a short `ssh lab` alias, and uses an SSH tunnel to reach nginx.

**Before you start:**
1. Keep **one logged-in ssh window open** for the whole chapter. If a change locks you out, that window is how you undo it.
2. Back up the config: `sudo cp /etc/ssh/sshd_config ~/sshd_config.bak`.
3. Only turn off passwords **after** key login is proven to work (10.2).

## 10.1 How key login works

| File | Lives on | Share it? |
|---|---|---|
| `id_ed25519` — **private key** | client (Windows `C:\Users\HP\.ssh\`) | **never** |
| `id_ed25519.pub` — **public key** | copied into the server's `~/.ssh/authorized_keys` | safe to share |

At login the server uses the public key to set a challenge that only the holder of the private key can answer. No password crosses the network. Memory hook: **`.pub` = public = the one that goes to the server.**

## 10.2 Make a key and put it on the server

On **Windows PowerShell**:

```powershell
PS> ssh-keygen -t ed25519            # Enter ×3: default path, empty passphrase (lab only)
PS> ls ~\.ssh
id_ed25519        411 bytes   ← private
id_ed25519.pub    101 bytes   ← public
known_hosts
```

Windows has no `ssh-copy-id`, so pipe the public key over ssh (asks for the password one last time):

```powershell
PS> type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh admin123@ubuntu-lab "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
```

| Part | Does |
|---|---|
| `type file \| ssh host "..."` | send the key's text into a command running on the VM |
| `mkdir -p ~/.ssh` | create the folder if missing |
| `cat >> authorized_keys` | **append** (`>` would wipe existing keys) |
| `chmod 700 ~/.ssh`, `chmod 600 authorized_keys` | only me |

**Why 700 / 600:** the last two digits are `0` — group and others get nothing. If someone else could **write** `authorized_keys`, they could add their own key and log in as me. sshd checks this and **ignores the key** if the folder or file is too open. The folder has `x` because you need `x` to enter a directory; `authorized_keys` is data that sshd reads, never runs, so it has no `x`.

Paths: Windows uses `\`, Linux uses `/`. PowerShell accepts both; inside the VM only `/` works.

## 10.3 Client alias: `~/.ssh/config`

On **Windows** (not the VM). Created with PowerShell because Notepad can silently add `.txt`:

```powershell
PS> @"
Host lab
    HostName 192.168.207.50
    User admin123
    IdentityFile ~/.ssh/id_ed25519
"@ | Set-Content -Encoding ascii $env:USERPROFILE\.ssh\config

PS> ssh lab
Welcome to Ubuntu 26.04.1 LTS ...        ← no password prompt = key login works
```

The config only stores the private key's **path**. What makes the login work is the pair: private key on Windows + public key in the VM's `authorized_keys`.

## 10.4 Turn off password and root login

### Read what is in effect now

```console
admin123@admin:~$ sudo sshd -T | grep -E "passwordauthentication|permitrootlogin"
permitrootlogin prohibit-password
passwordauthentication yes
```

`sshd -T` prints the settings sshd will **actually** use. `grep -E` lets `|` mean "or".

| `PermitRootLogin` | Meaning |
|---|---|
| `yes` | root with password or key |
| `prohibit-password` | root with key only (Ubuntu default) |
| `no` | root cannot log in over ssh at all |

Why `no`: everyone knows the name `root`, a root login has full power with no `sudo` step, and shared root hides who did what. I log in as `admin123` and use `sudo`.

### The trap: `sshd_config.d/` is read first

```console
admin123@admin:~$ ls /etc/ssh/sshd_config.d/
50-cloud-init.conf
admin123@admin:~$ grep -ri "passwordauthentication" /etc/ssh/sshd_config.d/
grep: ...50-cloud-init.conf: Permission denied          ← root-only file, needs sudo
admin123@admin:~$ sudo cat /etc/ssh/sshd_config.d/50-cloud-init.conf
PasswordAuthentication yes
```

`/etc/ssh/sshd_config` includes `sshd_config.d/*.conf` at the top, and for each setting **sshd keeps the first value it reads**. So editing the main file to `no` would do nothing: cloud-init's `yes` wins.

Fix: my own drop-in file whose name sorts **before** `50`:

```console
admin123@admin:~$ sudo nano /etc/ssh/sshd_config.d/00-hardening.conf
```

```
PasswordAuthentication no
PermitRootLogin no
```

I don't edit `50-cloud-init.conf`: it's generated and may be rewritten; my own file shows exactly what I changed.

### Check, then restart

```console
admin123@admin:~$ sudo sshd -t                     # lowercase: syntax check, no output = OK
admin123@admin:~$ sudo sshd -T | grep -E "passwordauthentication|permitrootlogin"
permitrootlogin no
passwordauthentication no
admin123@admin:~$ sudo systemctl restart ssh       # service is "ssh" on Ubuntu, not "sshd"
```

## 10.5 Verify from a new window

Open a **new** PowerShell window; keep the old session open.

| Test | Command | Result |
|---|---|---|
| key still works | `ssh lab` | ✅ in, no password |
| password only (pretend the key is missing) | `ssh -o PubkeyAuthentication=no admin123@ubuntu-lab` | ✅ `Permission denied (publickey).` |
| root | `ssh root@ubuntu-lab` | ✅ `Permission denied (publickey).` |

`(publickey)` is the list of login methods the server still accepts. Before the change it was `(publickey,password)`. Note test 2 **never asks for a password**: even someone who knows it has nowhere to type it.

**If key login breaks**, in the old window:

```console
admin123@admin:~$ sudo rm /etc/ssh/sshd_config.d/00-hardening.conf && sudo systemctl restart ssh
```

If every window is closed, log in at the VMware console (passwords still work there — this only affects ssh).

## 10.6 Local port forwarding: reach nginx through the tunnel

`-L local_port:target:target_port` opens a port on **my** machine and carries its traffic through the ssh connection (port 22); `target` is seen **from the server**.

```
browser → Windows :8080 ══ ssh tunnel over 22 (encrypted) ══> sshd in the VM → localhost:80 → nginx
```

```powershell
PS> ssh -L 8080:localhost:80 lab        # keep this window open
```

Browser: `http://localhost:8080` → nginx page.

```console
admin123@admin:~$ tail -n 3 /var/log/nginx/access.log
127.0.0.1 - - [21/Nov/2026:10:58:23 +0000] "GET / HTTP/1.1" 200 409 "-" "Mozilla/5.0 ... Edg/157.0.0.0"
127.0.0.1 - - [21/Nov/2026:10:58:23 +0000] "GET /favicon.ico HTTP/1.1" 404 197 "http://localhost:8080/" ...
```

The source is **`127.0.0.1`**, not Windows' `192.168.207.1`: nginx was reached by sshd from inside the VM. `127.0.0.1` lives on the loopback interface `lo` (`ip a show lo`), which every machine has; traffic to it never leaves the machine. The favicon 404 is just the browser asking for a site icon.

Real use: services that listen only on `127.0.0.1` (databases, admin pages) can be used from my laptop without opening any extra port. In Chapter 11 the firewall can block 80 and the tunnel still works, because it rides on 22.

## 10.7 SSH hardening checklist

- [x] Key pair made on the client (`ed25519`), private key never copied
- [x] Public key in `~/.ssh/authorized_keys`; `~/.ssh` 700, file 600
- [x] Key login tested **before** touching passwords
- [x] `/etc/ssh/sshd_config` backed up (`~/sshd_config.bak`)
- [x] `00-hardening.conf`: `PasswordAuthentication no`, `PermitRootLogin no` (sorts before `50-cloud-init.conf`)
- [x] `sshd -t` clean, `sshd -T` shows `no` / `no`, `systemctl restart ssh`
- [x] Verified from a new window: key ✅, password ❌, root ❌
- [x] Client alias `ssh lab`
- [ ] Firewall allows only the ports I need → [Chapter 11](11-firewall.md)

## 10.8 Commands

| Command | Use |
|---|---|
| `ssh-keygen -t ed25519` | make a key pair (client) |
| `type ~\.ssh\id_ed25519.pub \| ssh host "cat >> ~/.ssh/authorized_keys"` | copy the public key (Windows; Linux: `ssh-copy-id host`) |
| `~/.ssh/config` → `Host` / `HostName` / `User` / `IdentityFile` | client alias |
| `sudo sshd -t` | config syntax check |
| `sudo sshd -T \| grep -E "a\|b"` | settings in effect |
| `sudo systemctl restart ssh` | apply |
| `ssh -o PubkeyAuthentication=no user@host` | test that passwords are refused |
| `ssh -L 8080:localhost:80 lab` | local port forward |

## 10.9 Mistakes I made (Day 23)

| Wrote | Problem | Fix |
|---|---|---|
| warm-up: `find /etc/ssh -name *.conf 2>/dev/null` | no quotes: the shell may expand `*.conf` in the current folder first | `-name "*.conf"` |
| warm-up: `tar -czf ...` to copy a file from the VM | `tar` packs, `scp` copies | `scp admin123@ubuntu-lab:~/scripts.tar.gz .` (from → to) |
| warm-up: `sed notes.txt "yes/no"` | order reversed, no `s` / `g` | `sed 's/yes/no/g' notes.txt` |
| warm-up: nginx PID — didn't know | | `ps aux \| grep nginx` (PID = column 2) or `pgrep nginx` |
| thought `id_ed25519` goes to the server | that's the private key | the `.pub` file goes to the server |
| `grep -ri ... /etc/ssh/sshd_config.d/` → Permission denied | root-only file | `sudo` |
| "700/600 because the key must not be executable" | `x` is only half of it | the real reason: nobody else may **write** (add their own key) |
| closed the tunnel, page still loaded, `access.log` unchanged | browser showed a **cached** copy; no request reached nginx | `Ctrl+F5`, or check with `curl` / the log — the browser isn't proof |
