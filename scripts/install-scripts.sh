#!/bin/sh
# Copies the launcher scripts to $AUTOCAD_WINE_HOME and installs the desktop
# entries (AutoCAD, force close, sign-in URL handler).
set -eu

: "${AUTOCAD_WINE_HOME:=$HOME/.cache/wine-autocad-build}"
REPO=$(cd "$(dirname "$0")/.." && pwd)
APPS="$HOME/.local/share/applications"
mkdir -p "$AUTOCAD_WINE_HOME" "$APPS"

for s in wine-autocad autocad chiudi-autocad adsk-url-handler; do
    install -m 755 "$REPO/scripts/$s" "$AUTOCAD_WINE_HOME/$s"
done
for d in "$REPO"/desktop/*.desktop; do
    sed "s|@HOME@|$AUTOCAD_WINE_HOME|g" "$d" > "$APPS/$(basename "$d")"
done
xdg-mime default autocad-wine-signin.desktop x-scheme-handler/adskidmgr x-scheme-handler/adsk.idmgr
update-desktop-database "$APPS" 2>/dev/null || true
echo "Scripts installed in $AUTOCAD_WINE_HOME"
