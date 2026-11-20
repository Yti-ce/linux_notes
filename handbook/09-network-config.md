# 9. Network configuration: static IP and two NICs

*Day 22 (2026-11-20).* Until now `ens33` got its address from VMware's DHCP, so the IP could change (.129 → .130) and break my hosts file and ssh commands. A server needs a **fixed (static) IP**. This chapter sets one with netplan, then adds a second NIC on a host-only network.

**Before you start: take a VMware snapshot** (VM → Snapshot → Take Snapshot, `before-netplan`). A wrong network config cuts ssh; the snapshot is the undo button.

## 9.1 Read the current network

```console
admin123@admin:~$ ip -4 addr show ens33
    inet 192.168.207.130/24 metric 100 brd 192.168.207.255 scope global dynamic ens33
       valid_lft 1013sec preferred_lft 1013sec        ← "dynamic" + lease time = DHCP
admin123@admin:~$ ip route
default via 192.168.207.2 dev ens33 proto dhcp src 192.168.207.130 metric 100   ← default gateway
192.168.207.0/24 dev ens33 proto kernel scope link src 192.168.207.130 metric 100
192.168.207.2 dev ens33 proto dhcp scope link src 192.168.207.130 metric 100
admin123@admin:~$ ip -br link          # -br = one line per interface
```

A static config needs four things DHCP used to hand out:

| Item | Value | Where I got it |
|---|---|---|
| IP / prefix | `192.168.207.50/24` | chosen (see below) |
| Default gateway | `192.168.207.2` | `ip route` → `default via` |
| DNS | `192.168.207.2` | `resolvectl status` (Day 19) |
| Interface | `ens33` | `ip -br link` |

**Why .50 and not .130:** VMware's NAT DHCP hands out **.128–.254**. A static IP inside that range can be given to another VM by DHCP later → IP conflict. Pick one outside it.

## 9.2 What netplan is

```
/etc/netplan/*.yaml  →  netplan (translator)  →  systemd-networkd (does the work)  →  NIC gets its IP
```

I write *what I want* in YAML; netplan translates it for systemd-networkd, which actually runs DHCP or sets the address. **Editing the file changes nothing until `netplan try` / `netplan apply`.**

YAML rules: indentation = structure, **spaces only, no Tab**, siblings line up.

Original file (`/etc/netplan/00-installer-config.yaml`):

```yaml
network:
  version: 2
  ethernets:
    ens33:
      match:
        macaddress: "00:0c:29:fb:c4:c2"   # recognise the NIC by MAC
      dhcp4: true                         # ← IPv4 from DHCP
      dhcp6: true
      set-name: "ens33"                   # then name it ens33
```

## 9.3 Static IP on ens33

```console
admin123@admin:~$ sudo cp /etc/netplan/00-installer-config.yaml ~/netplan-backup.yaml   # backup first
admin123@admin:~$ sudo nano /etc/netplan/00-installer-config.yaml
```

```yaml
network:
  version: 2
  ethernets:
    ens33:
      match:
        macaddress: "00:0c:29:fb:c4:c2"
      set-name: "ens33"
      dhcp4: false                  # no more DHCP
      dhcp6: true
      addresses:
        - 192.168.207.50/24         # IP / prefix
      routes:
        - to: default
          via: 192.168.207.2        # default gateway
      nameservers:
        addresses: [192.168.207.2]  # DNS
```

Apply **from the VMware console, not over ssh**:

```console
admin123@admin:~$ sudo netplan try      # applies, then waits 120 s for Enter; no Enter → rolls back
```

`netplan try` is the safe version of `netplan apply`: if the new config locks you out, you can't press Enter, so it reverts by itself.

What happened to me: I ran it **over ssh to .130**. The IP changed, ssh died (`client_loop: send disconnect: Connection reset`). The network went back to DHCP .130, but the **file stayed changed** (the `try` process died with the ssh session before restoring it). So "the file" and "what is running" are two different things. Ran `sudo netplan try` again in the console, pressed Enter, then connected to the new IP. The console has no copy/paste, so: change in the console, check over ssh.

Check (over `ssh admin123@192.168.207.50`):

```console
admin123@admin:~$ ip -4 addr show ens33
    inet 192.168.207.50/24 brd 192.168.207.255 scope global ens33
       valid_lft forever preferred_lft forever          ← no "dynamic", lease = forever
admin123@admin:~$ ip route
default via 192.168.207.2 dev ens33 proto static        ← "static", not "dhcp"
192.168.207.0/24 dev ens33 proto kernel scope link src 192.168.207.50
admin123@admin:~$ ping -c 2 google.com                  ← gateway and DNS both work
64 bytes from ... (173.194.41.100): icmp_seq=1 ttl=128 time=15.9 ms
```

Then point the Windows hosts entry at the new IP (**administrator** PowerShell):

```powershell
$p = "C:\Windows\System32\drivers\etc\hosts"
(Get-Content $p) -replace '192.168.207.130','192.168.207.50' | Set-Content $p
Get-Content $p -Tail 2
```

## 9.4 Second NIC on a host-only network

NAT (VMnet8) lets the VM reach the internet. **Host-only (VMnet1)** is a private network between Windows and the VM only, no internet; like a management network on a real server.

Three things that are easy to mix up:

| Thing | What it is | Here |
|---|---|---|
| **VMnet1** | a virtual **switch** (the network), created when VMware is installed | `192.168.50.0/24` |
| Windows "VMware Network Adapter VMnet1" | **Windows' plug** into that switch | `192.168.50.1` |
| `ens37` in the VM | **the VM's plug**; VM Settings → Network Adapter 2 → **Host-only** | `192.168.50.10` (chosen) |

Two plugs talk only if they're on **the same switch** (host-only) **and in the same subnet** (192.168.50.x).

```console
admin123@admin:~$ ip -br link
lo     UNKNOWN  00:00:00:00:00:00 <LOOPBACK,UP,LOWER_UP>
ens33  UP       00:0c:29:fb:c4:c2 <BROADCAST,MULTICAST,UP,LOWER_UP>
ens37  UP       00:0c:29:fb:c4:cc <BROADCAST,MULTICAST,UP,LOWER_UP>   ← second NIC, no IP yet
```

Windows side: `ipconfig` → "VMware Network Adapter VMnet1" → `192.168.50.1 / 255.255.255.0`. (The VMnet2–19 adapters with `169.254.x.x` belong to other labs and have no address configured; ignore.)

Add to the same netplan file, `ens37:` lined up with `ens33:`:

```yaml
    ens37:
      dhcp4: false
      addresses:
        - 192.168.50.10/24
```

**No gateway on ens37.** One machine, one default route (internet via ens33). ens37 only talks to its own subnet, and the kernel adds that route automatically.

```console
admin123@admin:~$ sudo netplan try      # ens33 unchanged, so ssh survives; press Enter
admin123@admin:~$ ip -br addr
ens33  UP  192.168.207.50/24 ...
ens37  UP  192.168.50.10/24 ...
admin123@admin:~$ ip route
default via 192.168.207.2 dev ens33 proto static
192.168.50.0/24 dev ens37 proto kernel scope link src 192.168.50.10      ← added automatically
192.168.207.0/24 dev ens33 proto kernel scope link src 192.168.207.50
```

How the VM picks a NIC: match the destination against the table; a specific subnet wins, `default` only if nothing else matches.

| Destination | Matches | Out of | Gateway? |
|---|---|---|---|
| `192.168.50.1` | `192.168.50.0/24` | ens37 | no, direct |
| `192.168.207.1` | `192.168.207.0/24` | ens33 | no, direct |
| `8.8.8.8` | `default` | ens33 | yes, `192.168.207.2` |

From Windows, both paths into the VM work:

```powershell
PS> ping -n 2 192.168.50.10          # Reply from 192.168.50.10: TTL=64
PS> ssh admin123@192.168.50.10       # same host key as .207.50 / ubuntu-lab → same VM
```

## 9.5 Commands

| Command | Use |
|---|---|
| `ip -br link` / `ip -br addr` | interfaces / addresses, one line each |
| `ip -4 addr show ens33` | one interface; `dynamic` = DHCP |
| `ip route` | routing table; `default via` = gateway; `proto dhcp/static/kernel` = who added it |
| `sudo netplan try` | apply with 120 s auto-rollback (**from the console**) |
| `sudo netplan apply` | apply now, no rollback |
| `ls /etc/netplan/` | netplan config files |

## 9.6 Mistakes I made (Day 22)

| Wrote | Problem | Fix |
|---|---|---|
| warm-up: `find /etc -name /*.conf` | `-name` matches the file name only (no `/`); no quotes | `find /etc -name "*.conf" 2>/dev/null` |
| warm-up: nginx access records → `journalctl -u nginx` | that's the service's start/stop log | `tail -n 20 /var/log/nginx/access.log` |
| warm-up: cron line typed into the real crontab | backup now ran twice at 02:00 | removed the duplicate line; practice answers don't go into crontab |
| review: step ② of "type a URL" = hosts file | hosts belongs to step ① (DNS) | ② = routing + ARP |
| review: step ⑤ = `[P.]` | that's a TCP flag | ⑤ = HTTP (inside TLS) |
| review: "only the other side can read the private key" | the client never gets the private key | private key stays on the server, protected by `600` |
| `sudo cat /etc/nerplan/*.yaml` | typo | `netplan` |
| `netplan try` over ssh | changed the IP under my own ssh session | run it in the VMware console |
| typed `y` at the ssh host-key prompt | ssh wants the full word | `yes` |
| thought Windows' VMnet1 adapter and `ens37` were the same thing | one switch, two plugs | see 9.4 table |
