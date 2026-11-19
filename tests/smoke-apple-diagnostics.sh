#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/memory.sh"
source "$ROOT/lib/system.sh"

uname() { echo Darwin; }
sysctl() {
    if [[ "$1" == "vm.swapusage" ]]; then
        echo "vm.swapusage: total = 6144.00M used = 4788.50M free = 1355.50M (encrypted)"
    else
        return 1
    fi
}
[[ "$(swap_used_mb)" == "4788" ]]
[[ "$(swap_total_mb)" == "6144" ]]
[[ "$(power_mode)" == "Not applicable" ]]
echo "PASS macOS swap totals and power-mode reporting"
