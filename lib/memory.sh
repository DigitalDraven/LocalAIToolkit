#!/usr/bin/env bash

# Memory and swap helpers for Linux and macOS.

ram_available_mb() {
    if [[ "$(uname -s 2>/dev/null)" == "Darwin" ]]; then
        local page_size
        page_size="$(sysctl -n hw.pagesize 2>/dev/null || echo 4096)"
        vm_stat 2>/dev/null | awk -v p="$page_size" '
            /Pages free:/ {gsub(/\./,"",$3); f=$3}
            /Pages inactive:/ {gsub(/\./,"",$3); i=$3}
            /Pages speculative:/ {gsub(/\./,"",$3); s=$3}
            END {printf "%d", ((f+i+s)*p)/1048576}
        '
    else
        awk '/MemAvailable:/ {print int($2/1024)}' /proc/meminfo
    fi
}

swap_used_mb() {
    if [[ "$(uname -s 2>/dev/null)" == "Darwin" ]]; then
        sysctl vm.swapusage 2>/dev/null | sed -E 's/.*used = ([0-9.]+)M.*/\1/' | awk '{printf "%d", $1}'
    else
        free -m | awk '/^Swap:/ {print $3}'
    fi
}

swap_total_mb() {
    if [[ "$(uname -s 2>/dev/null)" == "Darwin" ]]; then
        sysctl vm.swapusage 2>/dev/null | sed -E 's/.*total = ([0-9.]+)M.*/\1/' | awk '{printf "%d", $1}'
    else
        free -m | awk '/^Swap:/ {print $2}'
    fi
}

_human_mb() {
    awk -v mb="${1:-0}" 'BEGIN { if (mb >= 1024) printf "%.1f GiB", mb/1024; else printf "%d MiB", mb }'
}

ram_summary() {
    if [[ "$(uname -s 2>/dev/null)" == "Darwin" ]]; then
        local total avail used
        total="$(sysctl -n hw.memsize 2>/dev/null | awk '{printf "%d", $1/1048576}')"
        avail="$(ram_available_mb)"
        used=$(( total > avail ? total-avail : 0 ))
        printf "%s used / %s total, %s available" "$(_human_mb "$used")" "$(_human_mb "$total")" "$(_human_mb "$avail")"
    else
        free -h | awk '/^Mem:/ {print $3 " used / " $2 ", " $7 " available"}'
    fi
}

swap_summary() {
    if [[ "$(uname -s 2>/dev/null)" == "Darwin" ]]; then
        sysctl vm.swapusage 2>/dev/null | sed -E 's/^vm.swapusage: //' || echo "unknown"
    else
        free -h | awk '/^Swap:/ {print $3 " used / " $2}'
    fi
}

ram_available_summary() {
    _human_mb "$(ram_available_mb)"
}
