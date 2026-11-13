# Chapter 2 — Users, groups and permissions

Goal: create users and a group, and give the group a shared directory that nobody else can open. Learned on **Day 3**, tested on **Day 7** (weakest round: 3/5). Lab record with full output: [permissions-lab.md](../permissions-lab.md). In-depth explanation in Chinese: [permissions-guide.md](../permissions-guide.md).

End state on the lab VM:

| Item | Value |
|---|---|
| Users | `alice`, `bob`, `carol` (home `/home/<name>`, shell `/bin/bash`, no `sudo`) |
| Group | `dev` = `alice`, `bob` |
| Shared directory | `/srv/dev`, `root:dev`, `770` |

## 2.1 Who am I

```console
admin123@admin:~$ id
uid=1000(admin123) gid=1000(admin123) groups=1000(admin123),4(adm),24(cdrom),27(sudo),...
```

Being in group `sudo` is what lets `admin123` run `sudo`. `groups` shows only the group names; `id alice` shows someone else.

## 2.2 Reading permissions

```console
admin123@admin:~$ ls -l /etc/passwd
-rw-r--r-- 1 root root 1743 Oct 29 07:28 /etc/passwd
```

Split the first 10 characters as 1 + 3 + 3 + 3:

```text
-     rw-     r--     r--
type  owner   group   others
```

Linux applies **only one** of the three sets: **owner** if I own the file, else **group** if I am in its group, else **others**.

| Letter | Value | On a file | On a directory |
|---|---|---|---|
| `r` | 4 | read contents | list names (`ls`) |
| `w` | 2 | modify | create / delete files inside |
| `x` | 1 | run as a program | enter it (`cd`) |

## 2.3 chmod: what people can do

Symbolic form — who (`u` owner, `g` group, `o` others) + `+`/`-` + letter:

```bash
chmod o-r test.txt     # others lose read
chmod g+w test.txt     # group gains write
chmod u+x run.sh       # owner may run it
```

Numeric form — **add inside each set, then write the three digits side by side**:

```text
want      owner rw-   group r--   others ---
add       4+2         4           0
digits    6           4           0          →  chmod 640 f
```

```text
0 ---   1 --x   2 -w-   3 -wx
4 r--   5 r-x   6 rw-   7 rwx
```

| Mode | Typical use |
|---|---|
| `644` | normal file |
| `600` | private file (keys, passwords) |
| `755` | directory or script (`/usr/local/bin/timestamp.sh` in [4.3](04-systemd.md#43-a-custom-service)) |
| `750` | home directory |
| `770` | group-shared directory |

Check: a digit of 1, 2 or 3 is almost always a mistake; real modes use 0, 4, 5, 6, 7. **Always `ls -l` right after `chmod` and compare with what you wanted.**

The owner can `chmod` their own files without `sudo`.

## 2.4 chown: whose file it is

```bash
sudo chown quizuser f            # owner only
sudo chown root:dev /srv/dev     # owner:group
sudo chown :dev f                # group only (= sudo chgrp dev f)
sudo chown -R alice:dev dir      # the directory and everything inside
```

- chmod = **ch**ange **mod**e (the 9 letters). chown = **ch**ange **own**er (the owner/group columns). After `chown` the 9 letters are unchanged.
- `chown` **always needs `sudo`**: a normal user cannot give files away.

## 2.5 Create users and a group

```bash
sudo useradd -m -s /bin/bash alice     # -m = make /home/alice (Ubuntu skips it otherwise), -s = login shell
sudo useradd -m -s /bin/bash bob
sudo useradd -m -s /bin/bash carol
sudo groupadd dev
sudo usermod -aG dev alice             # -a = append; without it the user's other groups are replaced
sudo usermod -aG dev bob
```

Verify:

```console
admin123@admin:~$ id bob
uid=1002(bob) gid=1002(bob) groups=1002(bob),1004(dev)
admin123@admin:~$ id carol
uid=1003(carol) gid=1003(carol) groups=1003(carol)
admin123@admin:~$ ls -l /home
drwxr-x--- 5 admin123 admin123 4096 Nov  2 04:51 admin123
drwxr-x--- 2 alice    alice    4096 Nov  2 05:02 alice
...
```

Home directories are `750`: other users cannot enter them. New users get no `sudo` (**least privilege**).

## 2.6 Shared directory for the group

```bash
sudo mkdir /srv/dev
sudo chown root:dev /srv/dev
sudo chmod 770 /srv/dev
ls -ld /srv/dev            # drwxrwx--- 2 root dev ... /srv/dev
```

Test as each user with `sudo -u <user> <command>`:

```console
admin123@admin:~$ sudo -u alice touch /srv/dev/alice.txt
admin123@admin:~$ sudo -u carol touch /srv/dev/carol.txt
touch: setting times of '/srv/dev/carol.txt': Permission denied
admin123@admin:~$ sudo -u carol ls /srv/dev
ls: cannot open directory '/srv/dev': Permission denied
```

| User | In `dev`? | Create file | List directory |
|---|---|---|---|
| alice | yes | ✅ | ✅ |
| carol | no | Permission denied | Permission denied |
| admin123 | no | Permission denied | Permission denied (Day 4: `tree /srv` → `dev [error opening dir]`) |

A new file belongs to **whoever created it** (`alice.txt` is `alice:alice`); it does not inherit the directory's owner or mode.

## 2.7 umask: default permissions of new files

New files start from `666`, new directories from `777`; the umask bits are removed.

| umask | New file | New directory | Where I saw it |
|---|---|---|---|
| `002` | 664 `rw-rw-r--` | 775 | my default as `admin123` |
| `022` | 644 `rw-r--r--` | 755 | files created through `sudo` |
| `077` | 600 `rw-------` | 700 | private files |

```bash
umask          # 0002
umask 077      # only for the current shell session
touch secret.txt && ls -l secret.txt   # -rw-------
```

## 2.8 Mistakes I made (Days 3 and 7)

| Typed | What happened | Fix |
|---|---|---|
| `chmod 16 test.txt` | added all three sets (6+6+4) → `------xrw-`, locked myself out | add **inside** each set: `chmod 664` |
| `chmod 620` for "group read" | group got `-w-` | group read = **4** → `640` |
| could not recall `chown` | — | `sudo chown owner:group file` |
| Day 7: did not know what `-m` in `useradd -m` does | — | `-m` = **m**ake the home directory `/home/<name>` |
| `sudo ls -l srv/dev` | `No such file or directory` | leading `/`: `/srv/dev` |
| `sudo -l /srv/dev` | wrong output | forgot `ls`: `sudo ls -l /srv/dev` |

## 2.9 Rebuild check (Day 11)

On Day 11 I rebuilt the whole setup from this chapter with new names, to prove the chapter is enough on its own. The Day 3 users and `/srv/dev` were still on the VM, so the rebuild used `tom`, `jerry`, `eve`, group `ops` and `/srv/ops`.

```bash
sudo useradd -m -s /bin/bash tom
sudo useradd -m -s /bin/bash jerry
sudo useradd -m -s /bin/bash eve
sudo groupadd ops
sudo usermod -aG ops tom
sudo usermod -aG ops jerry
sudo mkdir /srv/ops
sudo chown root:ops /srv/ops
sudo chmod 770 /srv/ops
```

Order to remember: **create group → add people → create directory → hand directory to group**. A group (`ops`) and a directory (`/srv/ops`) are two different things that only share a name.

Verify:

```console
admin123@admin:~$ id jerry
uid=1006(jerry) gid=1007(jerry) groups=1007(jerry),1009(ops)
admin123@admin:~$ id eve
uid=1007(eve) gid=1008(eve) groups=1008(eve)
admin123@admin:~$ ls -ld /srv/ops
drwxrwx--- 2 root ops 4096 Nov 13 07:34 /srv/ops
admin123@admin:~$ sudo -u tom touch /srv/ops/tom.txt
admin123@admin:~$ sudo -u tom ls -l /srv/ops
total 0
-rw-r--r-- 1 tom tom 0 Nov 13 07:40 tom.txt
admin123@admin:~$ sudo -u eve touch /srv/ops/eve.txt
touch: setting times of '/srv/ops/eve.txt': Permission denied
```

Result: same behaviour as Day 3. `tom` (in `ops`) can create files; `eve` (not owner, not in `ops`) only gets the "others" set `---`.

Mistakes during the rebuild:

| Typed | Error | Why / fix |
|---|---|---|
| `chmod 770 /srv/ops` | `Operation not permitted` | after `chown root:ops` I am no longer the owner; only the owner (or root) can `chmod` → `sudo chmod 770 /srv/ops` |
| `chmod 770 ops` | `No such file or directory` | `ops` is relative to my current directory `~`; write the absolute path `/srv/ops` |
| warm-up: could not write `ls -l /srv` | — | a path starting with `/` is absolute and works from anywhere |
| warm-up: could not recall how to change only the group | — | `sudo chown :adm f` (before the colon = owner, after = group, same order as `ls -l` columns 3 and 4) |

Reading errors: `Operation not permitted` / `Permission denied` → think permissions or `sudo`; `No such file or directory` → check the path.
