# Day 3 lab: users, groups and permissions

Ubuntu Server 26.04.1, logged in as `admin123` (member of `sudo`). Every output below is copied from my own terminal.

## 1. Who am I

```console
admin123@admin:~$ id
uid=1000(admin123) gid=1000(admin123) groups=1000(admin123),4(adm),24(cdrom),27(sudo),30(dip),46(plugdev),100(users),101(lxd)
```

Being in group `sudo` is what lets me run `sudo`.

## 2. Reading permissions

```console
admin123@admin:~$ ls -l /etc/passwd
-rw-r--r-- 1 root root 1743 Oct 29 07:28 /etc/passwd
```

Split the first 10 characters as 1 + 3 + 3 + 3:

```
-     rw-     r--     r--
type  owner   group   others
```

Linux applies **only one** of the three sets: owner if I own the file, else group if I am in its group, else others. For `/etc/passwd` I am "others" (`r--`), so I can read it but only `sudo` (root, `rw-`) can change it.

| Letter | On a file | On a directory |
|---|---|---|
| `r` (4) | read contents | list names (`ls`) |
| `w` (2) | modify | create / delete files inside |
| `x` (1) | run as a program | enter it (`cd`) |

## 3. chmod

Symbolic form: who (`u` `g` `o`) + `+`/`-` + permission.

```console
admin123@admin:~$ touch test.txt
admin123@admin:~$ ls -l test.txt
-rw-rw-r-- 1 admin123 admin123 0 Nov  2 04:51 test.txt
admin123@admin:~$ chmod o-r test.txt
admin123@admin:~$ ls -l test.txt
-rw-rw---- 1 admin123 admin123 0 Nov  2 04:51 test.txt
```

Numeric form: add the values **inside each set**, then write the three digits side by side.

```
0 ---   1 --x   2 -w-   3 -wx
4 r--   5 r-x   6 rw-   7 rwx
```

```console
admin123@admin:~$ chmod 750 test.txt
admin123@admin:~$ ls -l test.txt
-rwxr-x--- 1 admin123 admin123 0 Nov  2 04:51 test.txt
```

Mistake I made: `chmod 16` (I added 6+6+4). Linux read it as `016` and gave `------xrw-`, locking myself out. The owner can always fix it with `chmod 664`.

## 4. Users and a group

```console
admin123@admin:~$ sudo useradd -m -s /bin/bash alice     # -m: create /home/alice, -s: login shell
admin123@admin:~$ sudo useradd -m -s /bin/bash bob
admin123@admin:~$ sudo useradd -m -s /bin/bash carol
admin123@admin:~$ ls -l /home
drwxr-x--- 5 admin123 admin123 4096 Nov  2 04:51 admin123
drwxr-x--- 2 alice    alice    4096 Nov  2 05:02 alice
drwxr-x--- 2 bob      bob      4096 Nov  2 05:03 bob
drwxr-x--- 2 carol    carol    4096 Nov  2 05:03 carol
```

Home directories are `750`: other users cannot even enter them. New users get no `sudo` (**principle of least privilege**).

```console
admin123@admin:~$ sudo groupadd dev
admin123@admin:~$ sudo usermod -aG dev alice     # -a = append; without it other groups are replaced
admin123@admin:~$ sudo usermod -aG dev bob
admin123@admin:~$ id bob
uid=1002(bob) gid=1002(bob) groups=1002(bob),1004(dev)
admin123@admin:~$ id carol
uid=1003(carol) gid=1003(carol) groups=1003(carol)
```

## 5. Shared directory for the `dev` group

```console
admin123@admin:~$ sudo mkdir /srv/dev
admin123@admin:~$ sudo chown root:dev /srv/dev    # owner:group
admin123@admin:~$ sudo chmod 770 /srv/dev
admin123@admin:~$ ls -ld /srv/dev                 # -d: the directory itself, not its contents
drwxrwx--- 2 root dev 4096 Nov  2 05:18 /srv/dev
```

Test as other users with `sudo -u <user> <command>`:

```console
admin123@admin:~$ sudo -u alice touch /srv/dev/alice.txt
admin123@admin:~$ sudo -u carol touch /srv/dev/carol.txt
touch: setting times of '/srv/dev/carol.txt': Permission denied
admin123@admin:~$ sudo -u carol ls /srv/dev
ls: cannot open directory '/srv/dev': Permission denied
admin123@admin:~$ sudo ls -l /srv/dev
-rw-r--r-- 1 alice alice 0 Nov  2 05:18 alice.txt
```

| User | In `dev`? | Create file | List directory |
|---|---|---|---|
| alice | yes | OK | OK |
| carol | no | Permission denied | Permission denied |

Ownership is per file: `/srv/dev` belongs to `root:dev` (created with `sudo`), `alice.txt` belongs to `alice` (whoever creates a file owns it). A new file does **not** inherit the directory's permissions.

## 6. umask

New files start from `666`, new directories from `777`, then the umask bits are removed.

```console
admin123@admin:~$ umask
0002
```

| umask | New file | New directory | Where I saw it |
|---|---|---|---|
| `002` | 664 `rw-rw-r--` | 775 | my `test.txt` |
| `022` | 644 `rw-r--r--` | 755 | `alice.txt` (created through `sudo`) |
| `077` | 600 `rw-------` | 700 | private files (keys, passwords) |

```console
admin123@admin:~$ umask 077
admin123@admin:~$ touch secret.txt
admin123@admin:~$ ls -l secret.txt
-rw------- 1 admin123 admin123 0 Nov  2 05:39 secret.txt
```

`umask 077` lasts only for the current shell session.

## Errors I hit (and what they meant)

| What I typed | Error | Cause |
|---|---|---|
| `sudo -l /srv/dev` | wrong output | forgot `ls`; `sudo -l` is a different sudo option |
| `ls /sev/dev` | No such file or directory | typo (`srv`) |
| `sudo ls -l srv/dev` | No such file or directory | missing leading `/`, so it was a relative path from `~` |

Tip: use **Tab** completion for paths.
