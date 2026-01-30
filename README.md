# Server Performance Stats (server-stats.sh)

A lightweight Bash script that prints basic Linux server performance statistics in the terminal.

## What it shows

**Required stats**
- Total CPU usage
- Total memory usage (Used vs Free + percentage)
- Total disk usage (Used vs Free + percentage)
- Top 5 processes by CPU usage
- Top 5 processes by memory usage

**Optional / stretch stats (if available)**
- OS version
- Uptime
- Load average
- Logged-in users
- Failed login attempts (may require sudo)

---

## Project structure

```
.
├── server-stats.sh
└── README.md
```

---

## Requirements

- Any Linux distro with:
  - `bash`
  - Common utilities: `awk`, `ps`, `df`, `head`, `hostname`, `date`
- For extra stats (optional):
  - `who` (logged in users)
  - `lastb` (failed logins — often needs sudo/root)

Most servers already have these installed.

---

## How to run

1) Clone the repo (or download the script):
```bash
git clone <YOUR_GITHUB_REPO_URL>
cd <YOUR_REPO_FOLDER>
```

2) Make the script executable:
```bash
chmod +x server-stats.sh
```

3) Run it:
```bash
./server-stats.sh
```

> If you want to see failed login attempts and your system restricts access to `btmp`, run:
```bash
sudo ./server-stats.sh
```

---

## Example output

```
----------------------------------------------------------------------
SERVER PERFORMANCE STATS
----------------------------------------------------------------------
Host:  myserver
OS:    Ubuntu 22.04.4 LTS
Uptime: up 3 days, 2 hours
Load:  0.12 0.08 0.05
Time:  Thu Jan 30 12:00:00 UTC 2026

----------------------------------------------------------------------
Total CPU usage
----------------------------------------------------------------------
8.4%

----------------------------------------------------------------------
Total memory usage (Free vs Used including percentage)
----------------------------------------------------------------------
Used:  1.92 GiB (48.1%)
Free:  2.07 GiB (51.9%)
Total: 3.99 GiB

----------------------------------------------------------------------
Total disk usage (Free vs Used including percentage)
----------------------------------------------------------------------
Used:  18.23 GiB (36.5%)
Free:  31.74 GiB (63.5%)
Total: 49.97 GiB

----------------------------------------------------------------------
Top 5 processes by CPU usage
----------------------------------------------------------------------
PID     %CPU   COMMAND
1234    12.3   node
2222    8.7    python3
...

----------------------------------------------------------------------
Top 5 processes by memory usage
----------------------------------------------------------------------
PID     %MEM   COMMAND
3333    9.2    mongod
4444    7.1    java
...
```

---

## Notes / Implementation details (high level)

- **CPU usage** is calculated by sampling `/proc/stat` twice and computing active vs idle time.
- **Memory usage** uses `/proc/meminfo` (`MemTotal` and `MemAvailable`) to estimate free vs used memory accurately.
- **Disk usage** uses `df` and sums local filesystems (excluding `tmpfs` and `devtmpfs`) for a total view.
- **Top processes** are taken from `ps` sorted by CPU and memory.

---

## License

MIT (or remove this section if you don’t want to add a license yet)
