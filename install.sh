#!/usr/bin/env bash
set -u

INSTALL_DIR="$HOME/.local-ai-toolkit"
BIN_DIR="$HOME/bin"
LEGACY_DIR="$HOME/.super-orin-ai"
SRC="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

echo "Installing Local AI Toolkit v2.7.5..."
mkdir -p "$INSTALL_DIR" "$BIN_DIR"
mkdir -p "$INSTALL_DIR/models/orin-nano" "$INSTALL_DIR/models/agx-thor" "$INSTALL_DIR/models/dgx-spark" "$INSTALL_DIR/runtime/plugins"

cp -a "$SRC/lib" "$INSTALL_DIR/"
cp -a "$SRC/runtime" "$INSTALL_DIR/"
mkdir -p "$INSTALL_DIR/docs"
cp -a "$SRC/docs/." "$INSTALL_DIR/docs/"
rm -f "$INSTALL_DIR/docs/SWARMUI-COSMOS-NANO.md"
rm -rf "$INSTALL_DIR/media-studio"
cp -a "$SRC/media-studio" "$INSTALL_DIR/media-studio"
cp -a "$SRC/models/." "$INSTALL_DIR/models/"

# v2.7.0 intentionally retires the experimental Cosmos 3 Super profiles and
# their Diffusers plugin from the installed toolkit (does not touch HF cache).
rm -f "$INSTALL_DIR/models/dgx-spark/cosmos3-super-nf4-diffusers.conf" \
      "$INSTALL_DIR/models/dgx-spark/cosmos3-super-nf4.conf" \
      "$INSTALL_DIR/models/agx-thor/cosmos3-super-nf4.conf" \
      "$INSTALL_DIR/docs/COSMOS3-STATUS.md"
rm -rf "$INSTALL_DIR/runtime/plugins/cosmos3-diffusers"

cp "$SRC/start-ai" "$SRC/ai-status" "$SRC/ai-mode" "$SRC/ai-doctor" \
   "$SRC/ai-add-model" "$SRC/ai-edit-model" "$SRC/cosmos-media-studio" "$INSTALL_DIR/"

chmod +x "$INSTALL_DIR"/start-ai \
         "$INSTALL_DIR"/ai-status \
         "$INSTALL_DIR"/ai-mode \
         "$INSTALL_DIR"/ai-doctor \
         "$INSTALL_DIR"/ai-add-model \
         "$INSTALL_DIR"/ai-edit-model
chmod +x "$INSTALL_DIR/cosmos-media-studio"
rm -f "$INSTALL_DIR/swarmui"
chmod +x "$INSTALL_DIR"/lib/*.sh

# New command names
for cmd in start-ai ai-status ai-mode ai-doctor ai-add-model ai-edit-model cosmos-media-studio; do
    ln -sf "$INSTALL_DIR/$cmd" "$BIN_DIR/$cmd"
done

# Compat shims for 1.x command names
ln -sf "$INSTALL_DIR/ai-add-model"  "$BIN_DIR/super-orin-add-model"
ln -sf "$INSTALL_DIR/ai-edit-model" "$BIN_DIR/super-orin-edit-model"
ln -sf "$INSTALL_DIR/ai-status"     "$BIN_DIR/orin-status"
ln -sf "$INSTALL_DIR/ai-mode"       "$BIN_DIR/orin-mode"

# Migrate leftover 1.x llama.cpp profiles (copy, never delete).
migrated=0
if [[ -d "$LEGACY_DIR/models" ]]; then
    shopt -s nullglob
    for f in "$LEGACY_DIR/models"/*.conf; do
        base="$(basename "$f")"
        dest="$INSTALL_DIR/models/orin-nano/$base"
        if [[ ! -f "$dest" ]]; then
            cp "$f" "$dest"
            migrated=$((migrated + 1))
        fi
    done
    shopt -u nullglob
    if (( migrated > 0 )); then
        echo "Migrated $migrated Orin profile(s) from ~/.super-orin-ai into models/orin-nano/"
    else
        echo "No extra 1.x profiles to migrate from ~/.super-orin-ai"
    fi
    if [[ ! -e "$LEGACY_DIR/MOVED_TO_LOCAL_AI_TOOLKIT" ]]; then
        cat > "$LEGACY_DIR/MOVED_TO_LOCAL_AI_TOOLKIT" <<'NOTE'
This toolkit home is superseded by ~/.local-ai-toolkit (Local AI Toolkit v2.5).
Commands in ~/bin now point at the new install. You may remove this directory
after confirming your Orin model profiles exist under:
  ~/.local-ai-toolkit/models/orin-nano/
NOTE
    fi
fi

if ! grep -q 'HOME/bin' "$HOME/.bashrc" 2>/dev/null; then
    cat >> "$HOME/.bashrc" <<'EOFINNER'

# Local AI Toolkit
export PATH="$HOME/bin:$PATH"
EOFINNER
fi

echo
echo "Installed to: $INSTALL_DIR"
echo "Commands:"
echo "  start-ai"
echo "  ai-status"
echo "  ai-mode"
echo "  ai-doctor"
echo "  ai-add-model"
echo "  ai-edit-model"
echo "  cosmos-media-studio {start|stop|restart|status|logs}"
echo
echo "1.x names still work as shims: orin-status, orin-mode,"
echo "  super-orin-add-model, super-orin-edit-model"
echo
echo "If this shell does not know the commands yet, run:"
echo "  source ~/.bashrc"
echo
