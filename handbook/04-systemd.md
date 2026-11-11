# Chapter 4 — Service management with systemd

A **service** is a program that should run in the background all the time and start at boot (sshd, nginx). On Ubuntu, **systemd** manages services; you talk to it with **`systemctl`**.

## 4.1 Two independent switches: start vs enable

| Field in `systemctl status` | Meaning | Controlled by |
|---|---|---|
| `Active: active (running)` / `inactive (dead)` | running **now**? | `start` / `stop` / `restart` |
| `Loaded: ...; enabled;` / `disabled` | starts **at boot**? | `enable` / `disable` |

They do not affect each other. A service that is `inactive` + `enabled` **will** start after a reboot, because at boot systemd only looks at `enabled`.

```bash
sudo systemctl start   nginx   # run now
sudo systemctl stop    nginx   # stop now
sudo systemctl restart nginx   # stop + start (after changing a script/config)
sudo systemctl enable  nginx   # start at every boot
sudo systemctl disable nginx   # do not start at boot
systemctl status nginx         # q to quit
sudo systemctl daemon-reload   # after creating or editing a unit file
```

`●` = running, `○` = stopped, `×` = failed.

## 4.2 nginx

```bash
sudo apt update
sudo apt install -y nginx
systemctl status nginx              # active (running); enabled
curl http://localhost | head -n 5   # HTML from the VM itself
```

From the Windows browser: `http://<vm-ip>` → "Welcome to nginx!".

What the browser shows tells you where the problem is:

| Situation | Browser |
|---|---|
| VM up, nginx stopped or not installed | immediately `ERR_CONNECTION_REFUSED` (nothing listening on port 80) |
| VM off, or wrong IP | spins, then `ERR_CONNECTION_TIMED_OUT` |

`systemctl status nginx` also shows `ExecStartPre=/usr/sbin/nginx -t`: nginx tests its config before starting.

## 4.3 A custom service

**Script** `/usr/local/bin/timestamp.sh` (`/usr/local/bin` = programs I install myself):

```bash
#!/bin/bash
while true; do
    date >> /var/log/timestamp.log
    sleep 60
done
```

- `#!/bin/bash` (the *shebang*) must be the first line: it tells the system which interpreter runs the file.
- `while true` = loop forever; append the time every 60 s.

```bash
sudo chmod 755 /usr/local/bin/timestamp.sh   # rwxr-xr-x
```

**Unit file** `/etc/systemd/system/timestamp.service`:

```ini
[Unit]
Description=Write timestamp every minute

[Service]
ExecStart=/usr/local/bin/timestamp.sh
Restart=always

[Install]
WantedBy=multi-user.target
```

| Section | Purpose |
|---|---|
| `[Unit]` | description (and dependencies) |
| `[Service]` | **how to run it**: `ExecStart` = absolute path of the command; `Restart=always` = restart it if it exits |
| `[Install]` | **what `enable` does**: hook it into `multi-user.target` (normal boot finished) |

```bash
sudo systemctl daemon-reload
sudo systemctl start timestamp
sudo systemctl enable timestamp
# Created symlink '/etc/systemd/system/multi-user.target.wants/timestamp.service' → ...
systemctl status timestamp
```

`enable` simply creates that symlink in the boot list.

A running service can contain several processes. `CGroup` shows the script and its child:

```text
CGroup: /system.slice/timestamp.service
        ├─77757 /bin/bash /usr/local/bin/timestamp.sh
        └─77763 sleep 60
```

## 4.4 Troubleshooting: `start-limit-hit`

First start failed:

```text
× timestamp.service - Write timestamp every minute
     Active: failed (Result: start-limit-hit)
   Duration: 24ms
   Main PID: 77631 (code=exited, status=0/SUCCESS)
... Scheduled restart job, restart counter is at 5.
... Start request repeated too quickly.
```

Reading it:

1. `status=0/SUCCESS` after `24ms` → the script **ended normally**, but it should loop forever.
2. `Restart=always` restarted it; it exited again, 5 times in a row.
3. systemd gave up: *start request repeated too quickly*.

So the unit file was fine and the script was the problem:

```text
$ cat /usr/local/bin/timestamp.sh
#! /bin/bash
while ture; do
```

`ture` is not a command → it fails → `while` sees "false" → the loop never runs → the script exits with 0. Fixed to `true`, then:

```bash
sudo systemctl restart timestamp   # script changed, unit file did not → no daemon-reload needed
```

Lesson: when a service "succeeds" but dies instantly, read the script, not the unit file.

## 4.5 Verify start at boot

```bash
sudo reboot
# SSH drops; wait ~30 s; check the VM console for the (possibly new) IP
ssh admin123@192.168.207.130
systemctl status timestamp      # active (running) since 07:33:55
systemctl status nginx          # active (running) since 07:33:56
cat /var/log/timestamp.log
```

```text
Wed Nov 11 07:31:36 AM UTC 2026
Wed Nov 11 07:32:36 AM UTC 2026
Wed Nov 11 07:33:55 AM UTC 2026   ← 79 s gap = the reboot
Wed Nov 11 07:34:56 AM UTC 2026
```

✅ Both services came back on their own after the reboot.

> Don't trust "the command didn't print an error". Configure, then **verify**: here, by actually rebooting.
