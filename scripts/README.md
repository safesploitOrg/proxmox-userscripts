# Scripts

This directory contains modular Bash scripts designed for managing and auditing various aspects of a Proxmox VE environment.

Each subfolder categorises scripts by function or system component. Scripts are written with reusability, modularity, and auditability in mind — following best practices for DevSecOps-style infrastructure automation.

---

## 📂 Structure

### `lxc/`
Scripts specific to LXC containers.
- `audit-lxc.sh`: Checks resource limits, security settings (e.g. unprivileged mode), and mounts for all LXC containers.

### `qemu/`
Scripts specific to QEMU/KVM virtual machines.
- `audit-qemu.sh`: Verifies VM hardware configs, snapshot presence, and backup eligibility.

### `firewall/`
Scripts related to auditing or managing the Proxmox firewall.
- `audit-firewall.sh`: Compares current rules with a baseline and checks for exposed ports or missing rules.

### `backups/`
Backup-related automation or audits.
- `pve-backup-audit.sh`: Lists backups, age, and size across all VMs and containers.

### `misc/`
Miscellaneous utilities or pre-flight checks.
- `pre-start-checks.sh`: Can be run on system boot or cron to verify cluster health, free space, etc.

---

## ✅ Standards

- All scripts assume Bash (`#!/usr/bin/env bash`)
- Global variables defined in `ALL_CAPS` at the top of each script
- Functions used for modularity
- `main()` function pattern is followed
- Colour-coded output for readability
- Return codes and logging are handled consistently
- `lib/` functions (e.g. `utils.sh`) can be sourced where needed

---

## 🔐 Security

Scripts follow the principle of least privilege. Where possible:
- No root required unless essential
- Reads config from `../conf/`
- Uses `readonly` vars to avoid accidental mutation

---

