# Chapter 5 — Ops scripts

Three small bash scripts that every server needs in some form: **back up a directory**, **rename files in bulk**, **warn when the disk is filling up**. Source: [`scripts/`](scripts/). Learned on Day 10.

Each script was built in small steps: try the command by hand → minimal script → add one check at a time → test the normal case **and** the error cases.

## 5.1 Bash building blocks

### Exit codes and `$?`

Every command leaves an exit code in `$?`: **0 = success**, anything else = failure. `$?` only remembers the **last** command.

```text
admin123@admin:~$ ls /nothing
ls: cannot access '/nothing': No such file or directory
admin123@admin:~$ echo $?
2
admin123@admin:~$ ls /etc > /dev/null
admin123@admin:~$ echo $?
0
```

| Code | Seen when |
|---|---|
| `0` | success |
| `1` | general failure (my scripts use `exit 1`) |
| `2` | `ls`: serious trouble, e.g. file not found |
| `127` | **command not found**: check spelling and path (`~/scirpts/...` instead of `~/scripts/...`) |

`if` and `while` decide by exit code. That is why `while ture` (Chapter 4.4) never looped: `ture` is not a command, so it "failed".

### Variables

```bash
dir=/var/log        # store: no $, no spaces around =
echo "$dir"         # read: with $
ls "$dir"
```

- **Store without `$`, read with `$`.** `echo src` prints the letters `src`; `echo $src` prints the value.
- **No spaces around `=` and none inside the value** (or quote it: `msg="hello world"`).
  `dir=cat /var/log` did **not** set `dir`: bash ran `/var/log` as a command (`Is a directory`) and `$dir` stayed empty, so `ls $dir` listed the current directory.
- Check what a variable really holds with `echo "$var"`: the first debugging step.

### Arguments: `$1`, `$#`, `$0`

Words after the script name are its arguments, numbered automatically:

```text
~/scripts/hello.sh   Ytice   Kuala   Lumpur
                      $1      $2      $3          $# = 3
```

`$0` is the script's own name. Inside a **function**, `$1` means the function's first argument, not the script's.

### Command substitution `$(...)`

Run the command inside first, then put its output in that spot:

```text
admin123@admin:~$ echo "backup-$(date +%Y%m%d-%H%M%S).tar.gz"
backup-20261112-063340.tar.gz
```

### Tests in `[ ]`

| Test | True when |
|---|---|
| `[ -d "$x" ]` | `x` is an existing **directory** |
| `[ -f "$x" ]` | `x` is an existing regular **file** |
| `[ -e "$x" ]` | `x` exists |
| `[ -z "$x" ]` | `x` is **empty** (e.g. no argument given) |
| `[ "$a" = "$b" ]` | two strings are equal |
| `[ "$a" -gt 80 ]` / `-lt` | number greater / less than |
| `[ ! ... ]` | negate any test |

Rules: **spaces after `[` and before `]` and between every part**; always quote variables.

`[ -d"$1" ]` (missing space) is one single word, and `[ word ]` only asks "is this non-empty?", so it was **always true**: `checkdir.sh /nothing` said "is a directory".

### if, for, functions

```bash
if [ -d "$1" ]; then
    echo "$1 is a directory"
else
    echo "$1 not found"
    exit 1
fi

for f in ~/scripts/*.sh; do
    echo "Found script: $f"
done

greet() {
    echo "Hi, $1"
}
greet Ytice          # Hi, Ytice
```

## 5.2 `backup.sh`: archive a directory

[`scripts/backup.sh`](scripts/backup.sh) · Usage: `backup.sh <directory>` → `~/backups/backup-YYYYMMDD-HHMMSS.tar.gz`

`tar -czf <archive> <dir>`: **c**reate, g**z**ip-compress, **f**ile name follows. `Removing leading '/' from member names` is a notice, not an error.

**Why the checks matter.** The first version had none. Run without an argument:

```text
admin123@admin:~$ ~/scripts/backup.sh
tar: : Cannot stat: No such file or directory
tar: Exiting with failure status due to previous errors
Backup created: ~/backups/backup-20261112-070146.tar.gz
admin123@admin:~$ echo $?
0
```

tar failed, but the script still said "Backup created" and returned **0**, because `$?` is the code of the last command (`echo`). Run nightly with a wrong argument, this would "succeed" every day and back up nothing. Fixed with two guards:

```bash
if [ -z "$src" ]; then  ...usage...; exit 1; fi
if [ ! -d "$src" ]; then ...error...; exit 1; fi
```

Tests after the fix:

```text
admin123@admin:~$ ~/scripts/backup.sh
Usage: backup.sh <directory>                     (exit 1)
admin123@admin:~$ ~/scripts/backup.sh /nothing
Error: /nothing is not a directory               (exit 1)
admin123@admin:~$ ~/scripts/backup.sh ~/scripts
Backup created: ~/backups/backup-20261112-071924.tar.gz
```

`ls -l` header `total 8` is disk blocks used (KB), **not** the number of files.

## 5.3 `rename.sh`: add a prefix to many files

[`scripts/rename.sh`](scripts/rename.sh) · Usage: `rename.sh <directory> <prefix>`

Renaming in Linux is `mv`. Inside the script, `f` is a full path (`/home/admin123/lab/rename/old-a.txt`), so the file name is taken out first with `basename` before adding the prefix.

```text
admin123@admin:~$ ~/scripts/rename.sh ~/lab/rename new-
Renamed: old-a.txt -> new-old-a.txt
Renamed: old-b.txt -> new-old-b.txt
Renamed: old-c.txt -> new-old-c.txt
```

Checks: fewer than 2 arguments (`[ "$#" -lt 2 ]`) → usage; not a directory → error.

**Bug found by testing the normal case.** The directory check was written as `[ ! -d "dir" ]` (missing `$`). It tested for a folder literally named `dir`, so it failed every time:

```text
admin123@admin:~$ ~/scripts/rename.sh /nothing x-
Error: /nothing is not a directory               ← looked right, by accident
admin123@admin:~$ ~/scripts/rename.sh ~/lab/rename v2-
Error: /home/admin123/lab/rename is not a directory   ← wrong
```

Lesson: **test the success case too**. Testing only error cases let this bug pass.

## 5.4 `disk_alert.sh`: warn when the disk fills up

[`scripts/disk_alert.sh`](scripts/disk_alert.sh) · Usage: `disk_alert.sh <percent>` · exit 0 = OK, 1 = alert

Getting a bare number out of `df`:

```text
admin123@admin:~$ df -h /
Filesystem                         Size  Used Avail Use% Mounted on
/dev/mapper/ubuntu--vg-ubuntu--lv   27G  7.2G   18G  29% /
admin123@admin:~$ df --output=pcent / | tail -n 1 | tr -d ' %'
29
```

`tail -n 1` drops the `Use%` header; `tr -d ' %'` deletes spaces and `%`, because `-gt` only compares plain numbers.

```text
admin123@admin:~$ ~/scripts/disk_alert.sh 80
OK: disk usage 29%                               (exit 0)
admin123@admin:~$ ~/scripts/disk_alert.sh 20
ALERT: disk usage 29% is above 20%               (exit 1)
```

Earlier draft mistakes: the message had `29` typed in (must be `$usage`, or it reports 29% forever), and there was no `else`, so a healthy disk printed nothing. Chapter 7 runs this script from cron.

## 5.5 Checklist for any script

1. First line `#!/bin/bash`; `chmod 755`.
2. Check arguments first (`-z`, `$#`), print a `Usage:` line, `exit 1`.
3. Check inputs exist (`-d`, `-f`).
4. Quote every variable: `"$var"`.
5. Exit code tells the truth: `0` only on real success.
6. Test: no arguments, bad argument, **and** the normal case. Read the output, then `echo $?`.
7. No spaces in file names; copy syntax exactly (`-d "$x"`, not `-d"$x"`).
