#!/usr/bin/env bash

# Memory and swap helpers.

ram_available_mb() {
    awk '/MemAvailable:/ {print int($2/1024)}' /proc/meminfo
}

swap_used_mb() {
    free -m | awk '/^Swap:/ {print $3}'
}

ram_summary() {
    free -h | awk '/^Mem:/ {print $3 " used / " $2 ", " $7 " available"}'
}

swap_summary() {
    free -h | awk '/^Swap:/ {print $3 " used / " $2}'
}
