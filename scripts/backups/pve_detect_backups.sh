#!/bin/bash
#
# ----------------------------------------
# Script Name : pve_detect_backups.sh
# Author: Zepher @ safesploit
# Description : Detects Proxmox backups, shows size/date, supports filters and multiple formats.
# ----------------------------------------

# -----------------------------
# GLOBAL VARS
# -----------------------------
BACKUP_LOCATIONS=(
    "/var/lib/vz/dump"                # Local backup location
    # "/mnt/pve/NAS1A-pve-vol3/dump/"   # Remote backup location
    )
OLDER_THAN_DAYS=0
OUTPUT_MODE="text"  # Options: text, json, csv
ERROR_COUNT=0

declare -a RESULTS_JSON
declare -a RESULTS_CSV

# ANSI colours
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
RESET='\033[0m'

# -----------------------------
# USAGE & LOGGING
# -----------------------------
usage() {
    echo -e "${CYAN}Usage:${RESET}"
    echo -e "  $0 [-o|--old] [-j|--json] [-c|--csv] [-h|--help]"
    echo ""
    echo -e "${CYAN}Options:${RESET}"
    echo -e "  --older-than-30-days     Show backups older than 30 days"
    echo -e "  --older-than-90-days     Show backups older than 90 days"
    echo -e "  -o, --old                Shortcut for --older-than-30-days"
    echo -e "  -j, --json               Output in JSON format"
    echo -e "  -c, --csv                Output in CSV format"
    echo -e "  -h, --help               Show this help message"
    exit 0
}


log_info()  { [[ "$OUTPUT_MODE" == "text" ]] && echo -e "${CYAN}[INFO]${RESET} $*"; }
log_ok()    { [[ "$OUTPUT_MODE" == "text" ]] && echo -e "  ${GREEN}[PASS]${RESET} $*"; }
log_warn()  { [[ "$OUTPUT_MODE" == "text" ]] && echo -e "  ${YELLOW}[WARN]${RESET} $*"; ((ERROR_COUNT++)); }
log_fail()  { [[ "$OUTPUT_MODE" == "text" ]] && echo -e "  ${RED}[FAIL]${RESET} $*"; ((ERROR_COUNT++)); }

# -----------------------------
# HELPERS
# -----------------------------
get_file_size() {
    du -h "$1" | cut -f1
}

get_file_date() {
    date -r "$1" "+%Y-%m-%d"
}

get_file_age_days() {
    local epoch
    epoch=$(stat -c %Y "$1")
    echo $(( ( $(date +%s) - epoch ) / 86400 ))
}

format_backup_info() {
    local file="$1"
    local size date
    size=$(get_file_size "$file")
    date=$(get_file_date "$file")
    echo -e "| Size: ${YELLOW}$size${RESET} | Backup: ${CYAN}$date${RESET}"
}

add_result() {
    local location="$1" file="$2" size="$3" date="$4" status="$5"
    RESULTS_JSON+=("{\"location\":\"$location\",\"filename\":\"$file\",\"size\":\"$size\",\"backup_date\":\"$date\",\"status\":\"$status\"}")
    RESULTS_CSV+=("$location,$file,$size,$date,$status")
}

should_include_file() {
    local file="$1"
    [[ $OLDER_THAN_DAYS -eq 0 ]] && return 0

    local age
    age=$(get_file_age_days "$file")
    [[ $age -ge $OLDER_THAN_DAYS ]]
}

# -----------------------------
# CORE FUNCTION
# -----------------------------
scan_backup_location() {
    local location="$1"
    log_info "Scanning for backups in: $location"

    if [[ ! -d "$location" ]]; then
        log_fail "Backup location not found: $location"
        add_result "$location" "N/A" "0" "N/A" "MISSING"
        return
    fi

    local found_files=0
    shopt -s nullglob
    for file in "$location"/*.{tar,zst,lzo,gz}; do
        [[ -f "$file" ]] || continue
        found_files=1

        if ! should_include_file "$file"; then
            continue
        fi

        local filename size date
        filename=$(basename "$file")
        size=$(get_file_size "$file")
        date=$(get_file_date "$file")

        log_ok "$filename $(format_backup_info "$file")"
        add_result "$location" "$filename" "$size" "$date" "FOUND"
    done

    [[ $found_files -eq 0 ]] && log_warn "No backup files found in $location"
}

# -----------------------------
# OUTPUT FORMATS
# -----------------------------
output_json() {
    echo "["
    printf '  %s\n' "${RESULTS_JSON[@]}" | paste -sd "," -
    echo "]"
}

output_csv() {
    echo "Location,Filename,Size,Backup Date,Status"
    printf "%s\n" "${RESULTS_CSV[@]}"
}

# -----------------------------
# ARGUMENT PARSING
# -----------------------------
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -o|--older-than-30-days|--old)  OLDER_THAN_DAYS=30 ;;
            --older-than-90-days)           OLDER_THAN_DAYS=90 ;;
            -j|--json)                      OUTPUT_MODE="json" ;;
            -c|--csv)                       OUTPUT_MODE="csv" ;;
            -h|--help)                      usage ;;
            *) echo -e "${RED}Unknown argument: $1${RESET}"; usage ;;
        esac
        shift
    done
}

# -----------------------------
# MAIN
# -----------------------------
main() {
    parse_args "$@"

    for location in "${BACKUP_LOCATIONS[@]}"; do
        scan_backup_location "$location"
    done

    case "$OUTPUT_MODE" in
        json) output_json ;;
        csv)  output_csv ;;
    esac

    exit $ERROR_COUNT
}

main "$@"
