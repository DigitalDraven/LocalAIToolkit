#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/home" "$TMP/fakebin"
printf '# This comment mentions HOME/bin but is not a PATH export.\n' > "$TMP/home/.zshrc"
cat > "$TMP/fakebin/uname" <<'UNAME'
#!/usr/bin/env bash
echo Darwin
UNAME
chmod +x "$TMP/fakebin/uname"
HOME="$TMP/home" PATH="$TMP/fakebin:$PATH" bash "$ROOT/install.sh" >/dev/null
if ! grep -Eq '^[[:space:]]*export[[:space:]]+PATH=.*(\$HOME|\$\{HOME\})/bin' "$TMP/home/.zshrc"; then
    echo "FAIL installer did not add an active ~/bin PATH export"
    exit 1
fi
echo "PASS macOS installer adds PATH export when HOME/bin appears only in a comment"
