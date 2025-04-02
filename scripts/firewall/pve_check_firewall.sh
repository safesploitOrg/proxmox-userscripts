#!/bin/bash
#
# ============================================================
# Script Name : pve_check_firewall.sh
# Description : Audits Proxmox LXC and QEMU VM firewall config.
#               - Checks all network interfaces have firewall=1
#               - Checks guest firewall is enabled in <vmid>.fw
#               - Outputs as text, JSON, or CSV
#               - Supports warnings-only filter
#
# Usage       : ./pve_check_firewall.sh [-w] [-j] [-c] [-h]
#
# Options     :
#    -w   Show only warnings (suppress PASS entries in JSON/CSV)
#    -j   Output JSON only
#    -c   Output CSV only
#    -h   Show this help message
#
# Author      : Zepher Ashe (ChatGPT-collab, 2025)
# GitHub      : https://github.com/safesploitOrg
# License     : MIT
# Version     : 1.4.0
# ============================================================

# -----------------------------
# GLOBALS
# -----------------------------
OUTPUT_MODE="text"  # text, json, csv
SHOW_WARNINGS_ONLY=0
ERROR_COUNT=0

shopt -s nullglob

RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
RESET="\e[0m"

declare -a RESULTS_JSON
declare -a RESULTS_CSV

# -----------------------------
# LOGGING FUNCTIONS
# -----------------------------
log_info() {
    [[ "$OUTPUT_MODE" == "text" ]] && echo -e "${YELLOW}[INFO]${RESET} $*"
}
log_warn() {
    [[ "$OUTPUT_MODE" == "text" ]] && echo -e "${RED}[WARN]${RESET} $*" >&2
    ((ERROR_COUNT++))
}
log_ok() {
    [[ "$OUTPUT_MODE" == "text" && $SHOW_WARNINGS_ONLY -eq 0 ]] && echo -e "${GREEN}[PASS]${RESET} $*"
}

# -----------------------------
# USAGE
# -----------------------------
usage() {
    echo "Usage: $0 [-w] [-j] [-c] [-h]"
    echo ""
    echo "  -w   Show only warnings"
    echo "  -j   Output JSON only"
    echo "  -c   Output CSV only"
    echo "  -h   Show this help message"
    exit 0
}

# -----------------------------
# ARGUMENT PARSING
# -----------------------------
while getopts ":wjch" opt; do
    case "$opt" in
        w) SHOW_WARNINGS_ONLY=1 ;;
        j) OUTPUT_MODE="json" ;;
        c) OUTPUT_MODE="csv" ;;
        h) usage ;;
        \?) echo "Invalid option: -$OPTARG" >&2; usage ;;
    esac
done

# -----------------------------
# MAIN CHECK WRAPPER
# -----------------------------
check_firewall_flag() {
    local conf_file="$1"
    local id="$2"
    local type="$3"

    local if_status fw_status
    local if_msg="" fw_msg=""

    read -r if_status if_msg <<< "$(check_interfaces "$conf_file")"
    read -r fw_status fw_msg <<< "$(check_guest_firewall "$id")"

    record_result "$type" "$id" "$if_status" "$fw_status" "$if_msg" "$fw_msg"
}

# -----------------------------
# HELPERS
# -----------------------------
check_interfaces() {
    local conf_file="$1"
    local warning=0
    local net_lines
    net_lines=$(grep -E '^net[0-9]+:' "$conf_file" || true)

    while IFS= read -r line; do
        if [[ "$line" != *"firewall=1"* ]]; then
            warning=1
            echo "FAIL Interface missing firewall=1 → $line"
            return
        fi
    done <<< "$net_lines"

    echo "PASS All interfaces have firewall=1"
}

check_guest_firewall() {
    local id="$1"
    local fw_file="/etc/pve/firewall/$id.fw"

    if [[ ! -f "$fw_file" ]]; then
        echo "MISSING No firewall config file ($fw_file)"
    elif grep -q "^enable:\s*1" "$fw_file"; then
        echo "PASS Firewall ENABLED in $id.fw"
    else
        echo "FAIL Firewall DISABLED in $id.fw (enable: 0 or missing)"
    fi
}

record_result() {
    local type="$1"
    local id="$2"
    local if_status="$3"
    local fw_status="$4"
    local if_msg="$5"
    local fw_msg="$6"

    local if_coloured fw_coloured

    case "$if_status" in
        PASS) if_coloured="${GREEN}PASS${RESET}" ;;
        FAIL) if_coloured="${RED}FAIL${RESET}" ;;
        *)    if_coloured="${YELLOW}$if_status${RESET}" ;;
    esac

    case "$fw_status" in
        PASS) fw_coloured="${GREEN}PASS${RESET}" ;;
        FAIL) fw_coloured="${RED}FAIL${RESET}" ;;
        MISSING) fw_coloured="${YELLOW}MISSING${RESET}" ;;
        *) fw_coloured="$fw_status" ;;
    esac

    if [[ "$OUTPUT_MODE" == "text" ]]; then
        # Warnings
        [[ "$if_status" != "PASS" ]] && log_warn "$type $id: $if_msg"
        [[ "$fw_status" != "PASS" ]] && log_warn "$type $id: $fw_msg"

        # Summary
        if [[ "$if_status" == "PASS" && "$fw_status" == "PASS" ]]; then
            [[ "$SHOW_WARNINGS_ONLY" -eq 0 ]] && \
            echo -e "${GREEN}[PASS]${RESET} $type $id: Interface=$if_coloured, Firewall=$fw_coloured"
        else
            echo -e "${RED}[WARN]${RESET} $type $id: Interface=$if_coloured, Firewall=$fw_coloured"
        fi
    fi

    # Structured output filtering
    if [[ "$OUTPUT_MODE" != "text" && $SHOW_WARNINGS_ONLY -eq 1 ]]; then
        [[ "$if_status" == "PASS" && "$fw_status" == "PASS" ]] && return
    fi

    RESULTS_JSON+=("{\"type\":\"$type\",\"id\":\"$id\",\"interface_check\":\"$if_status\",\"firewall_enabled\":\"$fw_status\"}")
    RESULTS_CSV+=("$type,$id,$if_status,$fw_status")
}


# -----------------------------
# CT/VM CHECKS
# -----------------------------
check_lxc() {
    local lxc_confs=(/etc/pve/lxc/*.conf)
    [[ ${#lxc_confs[@]} -eq 0 ]] && log_info "No LXC containers found." && return

    [[ "$OUTPUT_MODE" == "text" ]] && echo -e "\n--- LXC Containers ---"
    for conf in "${lxc_confs[@]}"; do
        local vmid
        vmid="$(basename "$conf" .conf)"
        check_firewall_flag "$conf" "$vmid" "CT"
    done
}

check_qemu() {
    local vm_confs=(/etc/pve/qemu-server/*.conf)
    [[ ${#vm_confs[@]} -eq 0 ]] && log_info "No QEMU VMs found." && return

    [[ "$OUTPUT_MODE" == "text" ]] && echo -e "\n--- QEMU Virtual Machines ---"
    for conf in "${vm_confs[@]}"; do
        local vmid
        vmid="$(basename "$conf" .conf)"
        check_firewall_flag "$conf" "$vmid" "VM"
    done
}

check_cluster() {
    echo "TODO"
    # TODO:
    # - Adapt check_interfaces() to work with cluster networks
    # - Adapt check_guest_firewall() to work with cluster firewalls 
    # - Adapt check_firewall_flag() to work with cluster firewalls

    # What this does: 
    # - Check that all interfaces in the cluster have firewall=1
    # - Check that all firewalls in the cluster are enabled
}

# -----------------------------
# OUTPUT MODES
# -----------------------------
output_json() {
    echo "["
    local i
    for ((i = 0; i < ${#RESULTS_JSON[@]}; i++)); do
        local comma=","
        [[ $i -eq $((${#RESULTS_JSON[@]} - 1)) ]] && comma=""
        echo "  ${RESULTS_JSON[$i]}$comma"
    done
    echo "]"
}

output_csv() {
    echo "type,id,interface_check,firewall_enabled"
    for row in "${RESULTS_CSV[@]}"; do
        echo "$row"
    done
}

output_text() {
    echo "TODO"
    # TODO:

    # What this does: 
    # - Solididates text output into a function
}

print_summary() {
    if [[ "$OUTPUT_MODE" != "text" ]]; then
        [[ $ERROR_COUNT -gt 0 ]] && exit 1 || exit 0
    fi

    echo
    if [[ $ERROR_COUNT -gt 0 ]]; then
        echo -e "${RED}❌ Audit completed with $ERROR_COUNT warning(s)${RESET}"
        exit 1
    else
        echo -e "${GREEN}✅ All checks passed${RESET}"
        exit 0
    fi
}

# -----------------------------
# MAIN ENTRYPOINT
# -----------------------------
main() {
    [[ "$OUTPUT_MODE" == "text" ]] && echo "Running firewall audit on $(hostname)..."
    check_lxc
    check_qemu

    case "$OUTPUT_MODE" in
        json) output_json ;;
        csv)  output_csv ;;
    esac

    print_summary
}

main
