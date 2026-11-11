# Chapter 3 — Process management

Learned and written on **Day 8**.

A **program** is a file on disk; a **process** is a program that is running. Every process has a **PID** (process ID), which is how you find and stop it.

## 3.1 Listing processes

| Command | Shows |
|---|---|
| `ps` | only processes started in **this terminal** (e.g. `pts/0`) |
| `ps aux` | **every** process on the machine: `a` all users, `u` user/CPU%/MEM% columns, `x` processes without a terminal (most services) |
| `ps aux \| grep ssh` | filter by name |

```text
admin123@admin:~$ ps aux | grep ssh
root       58878  ...  sshd: /usr/sbin/sshd -D [listener] 0 of 10-100 startups
admin123   76462  ...  sshd-session: admin123@pts/0
admin123   76618  ...  grep --color=auto ssh
```

- Column 1 = user, column 2 = PID, last column = command.
- `sshd ... [listener]` (PID 58878, root) is the SSH service itself, waiting for new connections. Each login adds an `sshd-session` pair.
- The last line is `grep` itself (its own command line contains "ssh"). Ignore it.

## 3.2 Watching live: `top`

`top` refreshes every few seconds, sorted by CPU, highest first. Press `q` to quit.

```text
%Cpu(s): 46.7 us, ...
    PID USER      ... S  %CPU  %MEM     TIME+ COMMAND
  76635 admin123  ... R  99.7   0.2   0:22.91 yes
```

Why does one process show 99.7% while the whole machine shows ~47%? The VM has **2 CPU cores**. The process is using one full core; averaged over two cores that is about half.

## 3.3 Signals and `kill`

`kill` sends a **signal** to a process.

| Signal | Number | Meaning | Command |
|---|---|---|---|
| SIGTERM | 15 | "please exit": the process can save and clean up first. **Default.** | `kill PID` |
| SIGKILL | 9 | "stop now": the kernel ends it; no clean-up | `kill -9 PID` |

Practice: **TERM first, wait a few seconds, then `-9` only if it is still there.** Killing a database with `-9` can lose data.

The shell reports which one was used: `Terminated` = 15, `Killed` = 9.

## 3.4 Lab: find and stop a high-CPU process

**Create the problem:**

```bash
yes > /dev/null &
```

- `yes` prints `y` forever (originally used to auto-answer "are you sure? (y/n)" prompts), so it keeps one CPU core at 100%.
- `> /dev/null` sends the output to the "black hole" device, so the screen is not flooded.
- `&` runs it in the background; the shell prints `[1] <PID>`.

**Troubleshoot it (the real procedure):**

```text
# 1. Who is using the CPU?
top                       → yes, PID 76759, %CPU 99.8

# 2. Confirm the PID by name
admin123@admin:~$ ps aux | grep yes
admin123   76759 99.8  0.2  16112  7644 pts/0    R    06:29   0:08 yes
admin123   76770  0.0  0.0   6716  3016 pts/0    S+   06:29   0:00 grep --color=auto yes

# 3. Stop it (TERM first; -9 if it ignores TERM)
admin123@admin:~$ kill -9 76759
[1]+  Killed                     yes > /dev/null

# 4. Verify it is gone: only the grep line is left
admin123@admin:~$ ps aux | grep yes
admin123   76790  0.0  0.0   6716  3052 pts/0    S+   06:30   0:00 grep --color=auto yes
```

`top` shows the busiest processes, but it only fits a screenful. `ps aux | grep <name>` is the precise way to find a PID and to verify a process is gone.
