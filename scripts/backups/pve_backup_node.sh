#!/usr/bin/env bash

# ----------------------------------------
# PVE Node Config Backup Script
# Author: Zepher @ safesploit
# Description: Full config + metadata backup with absolute paths
# ----------------------------------------
# EXTRACTION:
#       tar -xzf pve-<hostname>-backup-<timestamp>.tar.gz
#
#   The archive preserves full paths, e.g.:
#       /etc/pve/qemu-server/100.conf
#       /etc/network/interfaces
#       /pve-meta-*/qemu_list.txt
# ----------------------------------------

# ========== GLOBAL VARS ==========
# Change BACKUP_DIR to an NFS share
BACKUP_DIR="/root/backups/pve-config"

TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
META_DIR="/pve-meta-${TIMESTAMP}"
HOSTNAME="$(hostname -s)"
ARCHIVE_NAME="pve-${HOSTNAME}-backup-${TIMESTAMP}.tar.gz"
TMP_FILELIST="$(mktemp)"

# ========== FUNCTIONS ==========

prepare_dirs() {
    echo "[INFO] Creating backup and metadata directories"
    mkdir -p "${BACKUP_DIR}"
    mkdir -p "${META_DIR}"
}

generate_metadata_files() {
    echo "[INFO] Generating metadata files"

    qm list > "${META_DIR}/qemu_list.txt"
    pct list > "${META_DIR}/lxc_list.txt"
    pveversion -v > "${META_DIR}/pve_version.txt"
}

create_filelist() {
    echo "[INFO] Creating file list with absolute paths"

    cat <<EOF > "${TMP_FILELIST}"
/etc/pve/qemu-server
/etc/pve/lxc
/etc/pve/firewall
/etc/pve/datacenter.cfg
/etc/pve/corosync.conf
/etc/pve/storage.cfg
/etc/hosts
/etc/network/interfaces
/etc/resolv.conf
${META_DIR}/qemu_list.txt
${META_DIR}/lxc_list.txt
${META_DIR}/pve_version.txt
EOF
}

create_archive() {
    echo "[INFO] Creating archive with full paths"
    tar -czpf "${BACKUP_DIR}/${ARCHIVE_NAME}" -T "${TMP_FILELIST}"
    echo "[SUCCESS] Backup saved to: ${BACKUP_DIR}/${ARCHIVE_NAME}"
}

cleanup() {
    echo "[INFO] Cleaning up temporary metadata and filelist"
    rm -rf "${META_DIR}"
    rm -f "${TMP_FILELIST}"
}

# ========== MAIN ==========
main() {
    echo "[START] Proxmox node config backup for: ${HOSTNAME}"

    prepare_dirs
    generate_metadata_files
    create_filelist
    create_archive
    cleanup

    echo "[DONE] Backup process completed"
}

main
