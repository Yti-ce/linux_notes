# Appendix A — Troubleshooting record

Failures I caused on purpose and then fixed: five Linux ones on **Day 14** (2026-11-17, A.1–A.5) and four network ones on **Day 25** (2026-11-23, A.7–A.10). The chapters are organised by *what I learned*; this appendix is organised by *what broke*, so it is the place to start when something is wrong.

## A.0 Symptom → first command

| Symptom | First command | Then |
|---|---|---|
| website down / service won't start | `systemctl status <svc>` | `sudo journalctl -u <svc> -n 20 --no-pager` → read the `[emerg]` / error line ([A.1](#a1-nginx-will-not-start-config-error), [A.4](#a4-nginx-will-not-start-port-already-in-use)) |
| config error `in <file>:<line>` | `sudo nano <file>` (root-owned → `sudo`) | `sudo nginx -t` **before** restart |
| disk almost full | `df -h /` | `sudo du -sh /* 2>/dev/null \| sort -h`, go one level deeper each time; `sudo ls -lah <dir>` for hidden files ([A.2](#a2-disk-almost-full)) |
| `Permission denied` for a user | reproduce as that user: `sudo -u <user> touch <path>` | `ls -ld <dir>` (the directory itself), `id <user>` ([A.3](#a3-shared-directory-permission-denied)) |
| `Address already in use` | `sudo ss -tlnp \| grep :<port>` | `sudo kill <PID>`, start the service again |
| cron job does nothing | `sudo journalctl -u cron --since "10 min ago"` | run the script by hand **as the same user**, `ls -l` the script ([A.5](#a5-cron-job-never-produces-output)) |
| a NIC's IP doesn't answer, other NICs fine | `ip -br addr` | IP wrong → `/etc/netplan/*.yaml` → `sudo netplan try` ([A.7](#a7-second-nic-unreachable-wrong-ip-in-netplan)) |
| `Connection refused` | `sudo ss -tlnp \| grep ':<port> '` | nobody listening → `systemctl status` → `journalctl -u` / `sudo sshd -t` ([A.8](#a8-ssh-connection-refused-typo-in-sshd-config)) |
| timeout, service fine inside | `sudo ufw status numbered` | rule order, first match wins ([A.9](#a9-website-times-out-from-one-machine-ufw-rule-order)) |
| IP works, name doesn't | `ping -n 1 <name>` (shows the IP it resolved to) | hosts file, then DNS server ([A.10](#a10-name-doesnt-work-ip-does-wrong-hosts-entry)) |

General method (from [6.2](06-logs.md#62-method)): **reproduce → read status/logs → find the exact cause → fix one thing → verify, including that nothing else broke.**

## A.1 nginx will not start (config error)

**Break:**

```bash
echo "server { listen 8080 }" | sudo tee /etc/nginx/conf.d/test.conf > /dev/null
sudo systemctl restart nginx      # fails
```

**Diagnose:**

```console
admin123@admin:~$ sudo journalctl -u nginx -n 20 --no-pager
... nginx[18998]: [emerg] 18998#18998: unexpected "}" in /etc/nginx/conf.d/test.conf:1
```

`unexpected "}"` means the problem is just **before** the `}`: every nginx directive ends with `;`.

**Fix and verify:**

```console
admin123@admin:~$ sudo nano /etc/nginx/conf.d/test.conf     # server { listen 8080; }
admin123@admin:~$ sudo nginx -t
nginx: configuration file /etc/nginx/nginx.conf test is successful
admin123@admin:~$ sudo systemctl restart nginx
admin123@admin:~$ systemctl status nginx
     Active: active (running) since Tue 2026-11-17 06:42:39 UTC; 13s ago
admin123@admin:~$ curl localhost
<title>Welcome to nginx!</title> ...
```

Clean-up: `sudo rm /etc/nginx/conf.d/test.conf`, `sudo nginx -t && sudo systemctl reload nginx` (`&&` = run the second only if the first succeeded).

**Gap found:** the handbook never said that editing a root-owned config file needs `sudo nano` / `sudo vim`.

## A.2 Disk almost full

**Break** (fill the disk, leave 1 GB):

```bash
sudo fallocate -l $(( $(df --output=avail -B1 / | tail -n 1) - 1073741824 )) /var/tmp/.cache_data
```

**Diagnose:**

```console
admin123@admin:~$ df -h /
Filesystem                         Size  Used Avail Use% Mounted on
/dev/mapper/ubuntu--vg-ubuntu--lv   27G   25G  1.0G  97% /
admin123@admin:~$ ~/scripts/disk_alert.sh 80
Tue Nov 17 06:55:45 AM UTC 2026 ALERT: disk usage 97% is above 80%
admin123@admin:~$ sudo du -sh /* 2>/dev/null | sort -h
...
3.8G    /swap.img
18G     /var
admin123@admin:~$ sudo du -sh /var/* 2>/dev/null | sort -h
...
17G     /var/tmp
admin123@admin:~$ sudo du -sh /var/tmp/* 2>/dev/null | sort -h
8.0K    /var/tmp/systemd-private-...      # only a few KB — where are the 17 GB?
admin123@admin:~$ sudo ls -lah /var/tmp
total 17G
-rw-r--r--  1 root root  17G Nov 17 06:45 .cache_data
```

| Part | Meaning |
|---|---|
| `du -s` / `-h` | one total per argument / sizes in K, M, G |
| `2>/dev/null` | throw away `Permission denied` noise |
| `sort -h` | sort human sizes; biggest **last** |
| `/var/tmp/*` | `*` does **not** match names starting with `.` → hidden file missing |
| `ls -lah` | `-a` shows hidden files |

**Fix and verify:**

```console
admin123@admin:~$ sudo rm /var/tmp/.cache_data
admin123@admin:~$ df -h /
/dev/mapper/ubuntu--vg-ubuntu--lv   27G  7.2G   18G  29% /
```

In real life: find out **who created the file and whether something still uses it** before deleting.

**Gap found:** `du` was not in the handbook; `df -h /` was only inside the script section ([5.4](05-scripts.md#54-disk_alertsh-warn-when-the-disk-fills-up)).

## A.3 Shared directory: Permission denied

**Break:**

```bash
sudo chown root:root /srv/ops
```

**Diagnose:**

```console
admin123@admin:~$ sudo -u tom touch /srv/ops/tom.txt
touch: setting times of '/srv/ops/tom.txt': Permission denied
admin123@admin:~$ sudo ls -l /srv/ops            # lists what is INSIDE
-rw-r--r-- 1 tom tom 0 Nov 13 07:40 tom.txt
admin123@admin:~$ sudo ls -ld /srv/ops           # the directory ITSELF
drwxrwx--- 2 root root 4096 Nov 13 07:40 /srv/ops
admin123@admin:~$ id tom
uid=1005(tom) gid=1006(tom) groups=1006(tom),1009(ops)
```

`tom tom` = owner `tom`, group `tom`: `useradd` gives every user a **private group** with the same name. `ops` is the **team group**.

**Fix — two wrong tries first:**

| Tried | Result |
|---|---|
| `sudo chown :dev /srv/ops` | `dev` is the Day 3 group (alice, carol); tom is not in it |
| `sudo chown :tom /srv/ops` | tom can write, but **jerry is now locked out** |
| `sudo chown :ops /srv/ops` | ✅ |

```console
admin123@admin:~$ ls -ld /srv/ops
drwxrwx--- 2 root ops 4096 Nov 17 07:11 /srv/ops
admin123@admin:~$ sudo -u tom touch /srv/ops/tom3.txt
admin123@admin:~$ sudo -u jerry touch /srv/ops/jerry.txt
```

Lessons: shared directories belong to the **team** group; verify **every** user who should have access, not only the one who complained. Permission digits (`770`) were fine — only the group was wrong.

## A.4 nginx will not start (port already in use)

**Break:**

```bash
sudo systemctl stop nginx
sudo nohup python3 -m http.server 80 > /dev/null 2>&1 &
sudo systemctl start nginx         # fails
```

**Diagnose, fix, verify:**

```console
admin123@admin:~$ sudo journalctl -u nginx -n 20 --no-pager
... nginx: [emerg] bind() to 0.0.0.0:80 failed (98: Address already in use)   (5 retries)
... nginx: [emerg] still could not bind()
admin123@admin:~$ sudo ss -tlnp | grep :80
LISTEN 0  5  0.0.0.0:80  0.0.0.0:*  users:(("python3",pid=19871,fd=3))
admin123@admin:~$ sudo kill 19871
[1]+  Terminated   sudo nohup python3 -m http.server 80 > /dev/null 2>&1
admin123@admin:~$ sudo systemctl start nginx
admin123@admin:~$ systemctl status nginx
     Active: active (running) since Tue 2026-11-17 07:18:21 UTC; 9s ago
admin123@admin:~$ curl localhost         # skipped on Day 14 — status "running" ≠ site works, always curl
```

`ss -tlnp`: **t** TCP, **l** listening, **n** numeric ports, **p** process (needs `sudo`).

## A.5 cron job never produces output

**Break:**

```bash
printf '#!/bin/bash\ndate >> /home/admin123/hello.log\n' > ~/scripts/hello.sh
chmod -x ~/scripts/hello.sh
(crontab -l; echo "* * * * * /home/admin123/scripts/hello.sh") | crontab -
```

Symptom: `~/hello.log` never appears.

**Diagnose:**

```console
admin123@admin:~$ sudo journalctl -u cron --since "10 min ago"
... CRON[20103]: (admin123) CMD (/home/admin123/scripts/hello.sh)
... CRON[20101]: (CRON) info (No MTA installed, discarding output)
admin123@admin:~$ sudo ~/scripts/hello.sh       # should have been without sudo, see below
sudo: cannot execute '/home/admin123/scripts/hello.sh': Permission denied (os error 13)
admin123@admin:~$ echo $?
1
admin123@admin:~$ ls -l ~/scripts/hello.sh
-rw-r--r-- 1 admin123 admin123 45 Nov 17 07:19 /home/admin123/scripts/hello.sh
```

- `CMD (...)` → cron **does** run it every minute; cron is fine.
- `No MTA installed, discarding output` → the script failed; cron tried to e-mail the error, there is no mail system, so the error was thrown away. The line has no `>> log 2>&1`, so nothing was kept.
- Reproduce **as the same user cron uses** (admin123), not with `sudo`.

**Fix and verify:**

```console
admin123@admin:~$ chmod +x ~/scripts/hello.sh         # my own file → no sudo
admin123@admin:~$ cat ~/hello.log
Tue Nov 17 07:34:01 AM UTC 2026
Tue Nov 17 07:35:01 AM UTC 2026
```

Clean-up: `crontab -e`, delete the `hello.sh` line, `crontab -l` shows only the two real jobs.

Lesson: every cron line gets `>> /home/admin123/cron.log 2>&1`, or its errors are lost (see [7.3](07-cron.md#73-my-jobs)).

## A.6 Mistakes I made (Day 14)

| Typed | Problem | Fix |
|---|---|---|
| `ls -l /srv/ops` to see the directory's owner | lists the contents | `ls -ld /srv/ops` |
| `chown :dev`, then `chown :tom` | wrong group, then the user's private group | team group `:ops`; check with `id <user>` |
| `sudo ~/scripts/hello.sh` to reproduce a cron failure | cron runs as admin123, not root | run it without `sudo` |
| stopped at `status: running` | process alive ≠ site reachable | `curl localhost` |

## Day 25 drills (2026-11-23)

Someone else breaks it; I only see the symptom. Same skeleton every time: **narrow it down → check layer by layer from the bottom → find who configured it → check before applying → verify from the other side.**

The symptom → first command rows are in [A.0](#a0-symptom--first-command).

## A.7 Second NIC unreachable (wrong IP in netplan)

**Break:** `sudo sed -i 's#192.168.50.10/24#192.168.5.10/24#' /etc/netplan/00-installer-config.yaml && sudo netplan apply` (only ens37 changes, so ssh over ens33 survives).

**Symptom:** `ping 192.168.50.10` from Windows times out; `ssh lab` (ens33) still fine → the problem is on **ens37 only**.

**Diagnose:**

```console
admin123@admin:~$ ip -br addr
ens37            UP             192.168.5.10/24 ...      ← link is UP, but the IP is wrong
```

`192.168.5.10` is not in Windows' VMnet1 network `192.168.50.0/24`, so nothing answers.

**Fix and verify:** `sudo nano /etc/netplan/00-installer-config.yaml` → `192.168.50.10/24` → `sudo netplan try` (Enter) → `ip -br addr` shows `.50.10` → ping from Windows works.

**Why the first ping timed out after the fix:** Windows first needs the VM's **MAC** (ARP request "who has 192.168.50.10?" → reply). The first packet waits for that; the rest use the ARP cache (`arp -a` on Windows). IP decides who it's for, MAC decides who gets it on this hop.

## A.8 ssh: Connection refused (typo in sshd config)

Rule: **keep the old ssh window open** the whole time; it is the lifeline (or use the VMware console).

**Break:** `echo 'PasswordAuthenticaton no' | sudo tee -a /etc/ssh/sshd_config.d/00-hardening.conf && sudo systemctl restart ssh`

**Symptom:** a new window: `ssh: connect to host 192.168.207.50 port 22: Connection refused` (key and password both).

**Diagnose:**

| Step | Command | Saw | Tells me |
|---|---|---|---|
| read the error word | `ssh lab` | `Connection refused` | packet arrived, **nobody listening** — not the firewall (that would be a timeout) |
| port | `sudo ss -tlnp \| grep ':22 '` | empty | sshd not listening |
| service | `sudo systemctl status ssh` | `failed` | it failed to start |
| why | `sudo journalctl -u ssh -n 20 --no-pager` | `00-hardening.conf: line 3: Bad configuration option: PasswordAuthenticaton` | file + line |

The last lines of a log are the conclusion (`Failed to start`); **the reason is a few lines above.**

**Fix and verify:** fix the spelling (or delete line 3: line 1 already says `PasswordAuthentication no`, and sshd uses the **first** value it sees) → `sudo systemctl restart ssh` → `sudo sshd -t` (no output = OK) → `sudo ss -tlnp | grep ':22 '` → `ssh lab` in a **new** window.

`sudo sshd -t` while the service is down may say `Missing privilege separation directory: /run/sshd`: `/run` lives in memory and systemd creates `/run/sshd` only when the service starts. A side effect of the service being down, not a config error.

**Why the old window never dropped:** `sshd -D [listener]` is the front desk that accepts new logins; each logged-in user gets their own `sshd-session` process. Restarting ssh kills only the front desk. Safe way to change sshd: **`sshd -t` → restart → test in a new window → only then close the old one.**

## A.9 Website times out from one machine (ufw rule order)

**Break:** `sudo ufw insert 1 deny from 192.168.207.1 to any port 80 proto tcp` (207.1 = Windows on VMnet8).

(First try was `sudo ufw insert 1 deny 80/tcp` → `Skipping inserting existing rule`: ufw compares only the **conditions** (port, protocol, source), not the action, so it keeps one rule per condition. `sudo ufw deny 80/tcp` would have turned the ALLOW into DENY: `Rule updated`.)

**Diagnose:** service → port → inside → firewall:

```console
admin123@admin:~$ sudo ss -tlnp | grep ':80 '
LISTEN 0 511 0.0.0.0:80 ... users:(("nginx",pid=1214,...))      ← listening (grep :80 alone also matches 8080)
admin123@admin:~$ sudo systemctl status nginx
     Active: active (running)                                      ← service fine
admin123@admin:~$ sudo ufw status numbered
[ 1] 80/tcp                     DENY IN     192.168.207.1          ← above the ALLOW
[ 4] 80/tcp                     ALLOW IN    Anywhere
```

**First match wins:** rules are checked top to bottom and the first one that matches decides. Packets from 207.1 hit [1] and are dropped; [4] is never reached. So specific rules go on top (`insert 1`), general ones below; a plain `ufw deny` is appended at the end and would never win against an earlier allow.

**Fix and verify:** `sudo ufw delete 1` (read the numbers first: a wrong number could delete 22) → `curl.exe -m 5 http://192.168.207.50` from Windows.

## A.10 Name doesn't work, IP does (wrong hosts entry)

**Break (Windows, admin PowerShell):** back up `hosts` to `$HOME\hosts.bak`, then change `192.168.207.50 ubuntu-lab` to `.51`.

**Symptom:** `curl.exe -m 5 http://192.168.207.50` works, `curl.exe -m 5 http://ubuntu-lab` doesn't → network, firewall and nginx are fine → **name resolution**.

**Diagnose:**

```powershell
PS> ping ubuntu-lab
正在 Ping ubuntu-lab [192.168.207.51] ...      ← resolved to the wrong IP; nothing lives on .51
```

Windows looks a name up in: **DNS cache → hosts file → DNS server.** Wrong answer → check hosts first (people edit it by hand), then the DNS server. `nslookup` asks the DNS server directly and **skips hosts**, so it can disagree with `ping`.

**Fix and verify:** admin PowerShell → `notepad C:\Windows\System32\drivers\etc\hosts` → `.50` → save (`ipconfig /flushdns` if ping still shows `.51`) → `ping ubuntu-lab` shows `[192.168.207.50]`, `curl.exe http://ubuntu-lab` shows the nginx page.

| Linux | Windows |
|---|---|
| `sudo nano /etc/hosts` | admin PowerShell, `notepad C:\Windows\System32\drivers\etc\hosts` |

## A.11 Mistakes I made (Day 25)

| Typed | Problem | Fix |
|---|---|---|
| forgot `ip -br addr` | the first check for any NIC/IP problem | `ip -br addr` (name / state / IP per line) |
| `ss -tlnp \| grep 22` | no `sudo` → no process column; `22` also matches `2222` | `sudo ss -tlnp \| grep ':22 '` |
| `curl.exe -m http://...` | `-m` needs seconds | `curl.exe -m 5 http://...` |
| `ufw status nembered` | typo | `numbered` |
