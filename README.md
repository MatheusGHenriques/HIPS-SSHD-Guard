# HIPS SSHD Guard

HIPS SSHD Guard is a lightweight Host Intrusion Prevention System (HIPS) written in **Bash** to protect Linux servers against SSHD brute-force attacks. It monitors authentication logs in real time, counts failures per IP, applies automatic firewall blocks, and records events for auditing.

## Features

* Continuous monitoring of `journalctl -u sshd` (or `/var/log/auth.log`).
* Automatic detection of SSH brute-force attacks.
* Failure counting per IP with configurable time window.
* Automatic blocking via `iptables` / `ip6tables` and scheduled unblocking.
* Persistent logs in `/var/tmp/hips.log`.
* Simple IP database in `/var/tmp/hips.db`.
* Automatic generation of the configuration file `/etc/hips.conf`.

## Usage

Run the script with root privileges:

```bash
sudo ./hips.sh
```

## Requirements

* Linux system with active SSHD  
* Bash
* Root permissions  
* `iptables` and `ip6tables`

## Limitations and considerations

* Educational-purpose project; not intended for critical environments.
* Does not replace full solutions (e.g., fail2ban, WAFs, commercial HIDS).
* Does not include advanced heuristics, behavioral analysis, or SIEM integration.

## License

Project licensed under GPL v3.0 - see `LICENSE` for details.
