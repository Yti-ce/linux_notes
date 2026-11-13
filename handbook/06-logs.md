# Chapter 6 — Logs and troubleshooting

Services run in the background: when they fail, nothing pops up on screen. The reason is in the **logs**. On Ubuntu, every systemd service writes to the **journal** (collected by `journald`); `journalctl` reads it. Learned on **Day 11**.

## 6.1 Reading the journal

| Command | Shows |
|---|---|
| `sudo journalctl -u nginx` | only the `nginx` service (`-u` = unit = the **service name**, not the program path) |
| `sudo journalctl -u nginx -n 20` | last 20 lines (like `tail -n`) |
| `sudo journalctl -u nginx -b` | only since this **boot** |
| `sudo journalctl -u nginx --since today` | since midnight; also `yesterday`, `"1 hour ago"` |
| `sudo journalctl --since "2026-11-13 06:55:50" --until "2026-11-13 06:56:10"` | **all services** in a time window (quote the time: it has a space) |
| `... --no-pager` | print everything, no pager, long lines not cut |
| `sudo journalctl -u nginx -f` | follow new lines live (`Ctrl+C` to stop) |

Each line is **time · host · program[PID]: message**:

```text
Nov 11 07:33:56 admin systemd[1]: Started nginx.service - A high performance web server...
```

In the pager (same as `less`): `→` scrolls right on cut lines (ending in `>`), space pages down, `q` quits.

Words to look for:

| Word | Meaning |
|---|---|
| `Starting` → `Started` | being started → start finished |
| `Stopping` → `Stopped` | being stopped → stop finished |
| `-- Boot <id> --` | the machine rebooted here |
| `[emerg]` | nginx's most serious error level |
| `Failed` / `Permission denied` / `status=203/EXEC` | see 6.3 |

**Rule:** current state comes from `systemctl status`; the journal tells you **what happened**. Always check the **date** of an error line first: on Day 11 I nearly debugged a two-day-old error.

`-u` takes the service name: `journalctl -u /usr/local/bin/timestamp.sh` → `-- No entries --`; `journalctl -u timestamp` works.

## 6.2 Method

1. `systemctl status <svc>` — is it running? the last few log lines are shown here too
2. `sudo journalctl -u <svc> -n 20 --no-pager` — find the error line, check its **time**
3. Something odd at a certain time? Drop `-u` and use `--since/--until` to see **everything** that happened then
4. Fix → **test** (`sudo nginx -t` for nginx) → `restart` → `status` again

## 6.3 Three failures I caused on purpose (Day 11)

### Case 0 (real, not on purpose): nginx restarted by itself

`journalctl -u nginx -b` ended with `Nov 13 06:55:59 Stopping nginx.service` but `status` said `active (running) since 06:55:59`. `-b` also showed the "current boot" started on **Nov 11**: the VM had been **suspended**, not rebooted.

Looking at that second for all services:

```text
Nov 13 06:55:58 admin systemd[1]: Reexecuting.
Nov 13 06:55:59 admin systemd[1]: Stopping chrony.service ...
Nov 13 06:55:59 admin systemd[1]: Stopping cron.service ...
Nov 13 06:55:59 admin systemd[1]: Stopping nginx.service ...
```

Cause: I had run a system update. It upgraded systemd (`Reexecuting`) and then restarted every service using old files (Ubuntu's needrestart). Nothing was broken.

### Case 1: config syntax error (nginx)

Break: back up, then delete the `;` at the end of `listen 80 default_server;`.

```bash
sudo cp /etc/nginx/sites-available/default ~/default.bak
sudo nano /etc/nginx/sites-available/default
sudo systemctl restart nginx
# Job for nginx.service failed because the control process exited with error code.
```

Find:

```console
admin123@admin:~$ sudo journalctl -u nginx -n 20 --no-pager
... [emerg] 10328#10328: invalid parameter "listen" in /etc/nginx/sites-enabled/default:23
```

- `sites-enabled/default` is a link to `sites-available/default`: same file.
- Without `;` nginx thinks the statement continues, so the **next** line's `listen` becomes an extra parameter. The reported line can be one **after** the real mistake.

Fix:

```bash
sudo nano +23 /etc/nginx/sites-available/default   # +23 = open at line 23; put the ; back
sudo nginx -t        # syntax is ok / test is successful
sudo systemctl restart nginx
```

Lesson: `restart` = stop + start. The stop succeeded and the start failed, so **the site was down**. Always `sudo nginx -t` **before** restarting.

### Case 2: port already in use (nginx)

Break: let another program take port 80 first.

```bash
sudo systemctl stop nginx
sudo python3 -m http.server 80 &     # & = run in the background
sudo systemctl start nginx           # fails
```

Find:

```text
nginx[10510]: nginx: [emerg] bind() to 0.0.0.0:80 failed (98: Address already in use)
```

`bind()` = claim a port. Who has it?

```bash
sudo ss -tlnp | grep :80
# ... users:(("python3",pid=10488,...))
```

`ss -tlnp`: **t** TCP, **l** listening only, **n** numeric ports, **p** show process.

Fix:

```bash
sudo kill 10488          # [1]+ Terminated  sudo python3 -m http.server 80
sudo systemctl start nginx
```

`sudo` is needed for `kill` because the process belongs to root.

### Case 3: missing execute permission (custom service)

Break: remove `x` from the script that `timestamp.service` runs (Chapter 4.3).

```bash
sudo chmod 644 /usr/local/bin/timestamp.sh     # rw-r--r--
sudo systemctl restart timestamp
```

Find:

```console
admin123@admin:~$ sudo journalctl -u timestamp --since today --no-pager
... timestamp.service: Failed at step EXEC spawning /usr/local/bin/timestamp.sh: Permission denied
... timestamp.service: Main process exited, code=exited, status=203/EXEC
... timestamp.service: Scheduled restart job, restart counter is at 5.
... timestamp.service: Start request repeated too quickly.
```

- `203/EXEC` = the program could not be started at all → check the path and the `x` permission.
- `Restart=always` retried 5 times, then systemd gave up (same mechanism as `start-limit-hit` in [4.4](04-systemd.md#44-troubleshooting-start-limit-hit), different cause).

Fix:

```bash
sudo chmod 755 /usr/local/bin/timestamp.sh     # rwxr-xr-x
sudo systemctl restart timestamp
```

## 6.4 Error → first thing to check

| Error text | Check |
|---|---|
| `[emerg] ... in <file>:<line>` | that line **and the one before**; `sudo nginx -t` |
| `Address already in use` | `sudo ss -tlnp \| grep :<port>` → stop or `kill` the other program |
| `Permission denied`, `203/EXEC` | `ls -l` the file: owner, `x` bit; path spelled right |
| `Start request repeated too quickly` | not the cause: scroll **up** to the first failure |
| `-- No entries --` | wrong service name after `-u`, or wrong time range |

## 6.5 Mistakes I made (Day 11)

| Typed | Problem | Fix |
|---|---|---|
| answered "last start = Nov 13 06:55:59" | that line said `Stopping` | read the verb: `Started` = started |
| `journalctl -u /usr/local/bin/timestamp.sh` | `-- No entries --` | `-u timestamp` (service name) |
| pasted a `Nov 11` error as today's cause | old entry | check the date; use `--since today` |
| forgot how to end a process | — | `sudo kill <PID>` (Chapter 3) |
| `chmod 755 /usr/local/bin/timestamp.sh` | `Operation not permitted` | file is `root:root`; only the owner may chmod → `sudo chmod` (same mistake as [2.9](02-permissions.md#29-rebuild-check-day-11)) |
