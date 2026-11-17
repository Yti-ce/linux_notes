# Appendix A — Troubleshooting record

Five failures I caused on purpose on **Day 14** (2026-11-17) and then fixed using only this handbook. The chapters are organised by *what I learned*; this appendix is organised by *what broke*, so it is the place to start when something is wrong.

## A.0 Symptom → first command

| Symptom | First command | Then |
|---|---|---|
| website down / service won't start | `systemctl status <svc>` | `sudo journalctl -u <svc> -n 20 --no-pager` → read the `[emerg]` / error line ([A.1](#a1-nginx-will-not-start-config-error), [A.4](#a4-nginx-will-not-start-port-already-in-use)) |
| config error `in <file>:<line>` | `sudo nano <file>` (root-owned → `sudo`) | `sudo nginx -t` **before** restart |
| disk almost full | `df -h /` | `sudo du -sh /* 2>/dev/null \| sort -h`, go one level deeper each time; `sudo ls -lah <dir>` for hidden files ([A.2](#a2-disk-almost-full)) |
| `Permission denied` for a user | reproduce as that user: `sudo -u <user> touch <path>` | `ls -ld <dir>` (the directory itself), `id <user>` ([A.3](#a3-shared-directory-permission-denied)) |
| `Address already in use` | `sudo ss -tlnp \| grep :<port>` | `sudo kill <PID>`, start the service again |
| cron job does nothing | `sudo journalctl -u cron --since "10 min ago"` | run the script by hand **as the same user**, `ls -l` the script ([A.5](#a5-cron-job-never-produces-output)) |

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
