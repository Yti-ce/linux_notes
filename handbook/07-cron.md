# Chapter 7 — Scheduled jobs with cron

Goal: run the Chapter 5 scripts automatically — disk check every 5 minutes, backup every night — with their output (and errors) in a log file. Learned on **Day 13** (first pass 11-13, redone 11-16).

## 7.1 What cron is

`cron` is a service that is always running (`systemctl status cron`). Every minute it checks each user's job table, the **crontab**, and runs whatever is due.

```bash
crontab -l      # list my jobs  ("no crontab for admin123" at first)
crontab -e      # edit them (first time: choose 1 = nano)
```

Saving prints `crontab: installing new crontab`. Jobs run as the user who owns the crontab.

## 7.2 The five time fields

```text
min  hour  day  month  weekday   command
*/5  *     *    *      *         /home/admin123/scripts/disk_alert.sh 80 >> /home/admin123/cron.log 2>&1
```

| Field | Range |
|---|---|
| minute | 0–59 |
| hour | 0–23 |
| day of month | 1–31 |
| month | 1–12 |
| weekday | 0–7 (0 and 7 = Sunday) |

`*` = every, `*/N` = every N, a number = only then. Read left to right; **minute comes first**.

| Schedule | Meaning |
|---|---|
| `* * * * *` | every minute |
| `*/5 * * * *` | every 5 minutes |
| `0 2 * * *` | every day at 02:00 |
| `0 8 * * *` | every day at 08:00 — **not** `* 8 * * *` (that is every minute from 08:00 to 08:59) |
| `0 9 * * 1` | Mondays at 09:00 |

Time is the **VM's clock, UTC** (Beijing − 8 h): `0 2 * * *` runs at 10:00 Beijing time.

Everything after the fifth field is handed to `/bin/sh` exactly as typed, the same as typing it in a terminal.

## 7.3 My jobs

```console
admin123@admin:~$ crontab -l | tail -n 2
*/5 * * * * /home/admin123/scripts/disk_alert.sh 80 >> /home/admin123/cron.log 2>&1
0 2 * * * /home/admin123/scripts/backup.sh /home/admin123/scripts >> /home/admin123/cron.log 2>&1
```

- **Absolute path** to the script (see 7.5).
- `>> /home/admin123/cron.log` appends normal output (stream 1).
- `2>&1` sends errors (stream 2) to the same place. Without it, errors from cron jobs are lost.
- In `backup.sh /home/admin123/scripts` the first path is the **script**, the second is its **argument** (the directory to back up). `<directory>` in a usage line is a placeholder: do not type the `< >`.

Timestamps: cron.log was full of identical `OK: disk usage 29%` lines with no way to tell when. [`disk_alert.sh`](scripts/disk_alert.sh) now prints `$(date)` first:

```text
Mon Nov 16 03:15:01 PM UTC 2026 OK: disk usage 29%
```

`tar: Removing leading '/' from member names` in the log is a notice, not an error (tar stores `/home/...` as `home/...`). It appears because `2>&1` also captures notices.

## 7.4 Testing a job

1. Try the command in a terminal first.
2. Schedule it every minute or two (`* * * * *`, `*/2 * * * *`), check the log or the output files.
3. **Change it to the real schedule straight away.**

Lesson: on 11-13 I tested the backup with `*/2` and did not switch it back. Three days later `~/backups` held **108** archives (only 108 because cron does not run while the VM is suspended). Fixed to `0 2 * * *`, then cleaned up:

```bash
ls ~/backups/backup-20261113-*     # preview what the pattern matches
rm ~/backups/backup-20261113-*     # then delete the same pattern
```

Always `ls` a wildcard before `rm` with it: there is no recycle bin.

## 7.5 Why cron jobs fail when the terminal works

### PATH

A command **without `/`** (`date`, `disk_alert.sh`) is looked up in the directories listed in `$PATH`. A command **with `/`** (`~/scripts/x.sh`, `/home/...`) is used as given; PATH is not consulted.

```console
admin123@admin:~$ echo $PATH
/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin
```

On many systems cron's PATH is only `/usr/bin:/bin`. On this Ubuntu VM cron reads `/etc/environment`, so a test job (`echo "$PATH" > ~/cron_path.txt`) showed the same PATH as the terminal. Either way `~/scripts` is in neither, so **always write absolute paths in crontab**.

Broken on purpose:

```text
* * * * * disk_alert.sh 80 >> /home/admin123/cron.log 2>&1
```

```text
/bin/sh: 1: disk_alert.sh: not found
```

Fix: `/home/admin123/scripts/disk_alert.sh`.

### `%` in crontab

In a crontab line `%` means "newline". Broken on purpose (works in a terminal):

```text
* * * * * echo "$(date +%F) test" >> /home/admin123/cron.log 2>&1
```

Nothing appeared in cron.log, not even an error. cron's own log showed why:

```console
admin123@admin:~$ sudo journalctl -u cron --since "10 min ago" --no-pager | tail -n 10
... (admin123) CMD (echo "$(date +)
... (CRON) info (No MTA installed, discarding output)
```

The command was cut at `%`, so `>>` and `2>&1` were never part of it; the error was meant to be e-mailed and was thrown away. Fix: `date +\%F`. Better: keep anything with `%` inside the script and keep the crontab line to *schedule + absolute path + redirection*.

## 7.6 Troubleshooting checklist

| Symptom | Check |
|---|---|
| job never seems to run | `sudo journalctl -u cron --since "10 min ago"`: is there a `CMD (...)` line, and is the command complete? |
| `not found` in the log | absolute path; spelling (`bcakup.sh`) |
| nothing in the log at all | `%` not escaped; `2>&1` missing; `No MTA installed, discarding output` |
| runs at the wrong time | fields in the wrong order; UTC vs local time; `*` where `0` was meant |
| too many output files | a test schedule (`*/2`) left in place |

## 7.7 Mistakes I made (Day 13)

| Typed | Problem | Fix |
|---|---|---|
| `*8***` for "08:00 daily" | no spaces; minute `*` = every minute | `0 8 * * *` |
| `*/2 * * * * bcakup.sh </home/admin123/scripts>` | typo, no path, typed the `< >` placeholder | `/home/admin123/scripts/backup.sh /home/admin123/scripts` |
| left the `*/2` backup test in place | 108 archives in 3 days | switch to the real schedule right after testing |
| warm-up: `head -n 5 ~/cron.log` for the last lines | head = first | `tail -n 5` — newest lines are at the end |
| warm-up: `journalctl -u nginx since today` | missing `--` and `sudo` | `sudo journalctl -u nginx --since today` |
