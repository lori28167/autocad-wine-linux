#!/bin/sh
# Prepares the Wine prefix for AutoCAD 2026: runtimes, Windows version,
# WebView2 109 runtime and a "Microsoft Sans Serif" substitute font.
# Run after build-wine.sh and install-scripts.sh.
set -eu

: "${AUTOCAD_WINE_HOME:=$HOME/.cache/wine-autocad-build}"
: "${WINEPREFIX:=$HOME/.wine-autocad}"
export WINEPREFIX
REPO=$(cd "$(dirname "$0")/.." && pwd)
WA="$AUTOCAD_WINE_HOME/wine-autocad"
export WINE="$AUTOCAD_WINE_HOME/wine-custom/bin/wine"
export WINESERVER="$AUTOCAD_WINE_HOME/wine-custom/bin/wineserver"
export WINEDEBUG=-all
reg() { "$WA" reg add "$@" /f >/dev/null; }

# 1. Runtimes. Do NOT add msxml3/msxml6: winetricks installs only a 32-bit
#    native msxml3 and the 64-bit acad.exe then fails to start.
winetricks -q corefonts vcrun2022 dotnet48
winetricks -q win11
K='HKLM\Software\Microsoft\Windows NT\CurrentVersion'
reg "$K" /v CurrentBuild /t REG_SZ /d 22631
reg "$K" /v CurrentBuildNumber /t REG_SZ /d 22631
reg "$K" /v DisplayVersion /t REG_SZ /d 23H2

# 2. Edge WebView2 fixed-version runtime 109 (newer ones need DirectComposition).
D="$AUTOCAD_WINE_HOME/wv2-109"
mkdir -p "$D/rt"
[ -f "$D/rt.nupkg" ] || curl -fL -o "$D/rt.nupkg" https://www.nuget.org/api/v2/package/WebView2.Runtime.X64/109.0.1518.78
bsdtar -xf "$D/rt.nupkg" -C "$D/rt" 'contentFiles/any/any/WebView2/*'
rm -rf "$WINEPREFIX/drive_c/wv2-109"
cp -r "$D/rt/contentFiles/any/any/WebView2" "$WINEPREFIX/drive_c/wv2-109"
reg 'HKCU\Software\Wine\AppDefaults\msedgewebview2.exe' /v Version /d win7
reg 'HKLM\Software\Policies\Microsoft\Edge\WebView2\BrowserExecutableFolder' /v '*' /d 'C:\wv2-109'
reg 'HKLM\Software\WOW6432Node\Policies\Microsoft\Edge\WebView2\BrowserExecutableFolder' /v '*' /d 'C:\wv2-109'

# 3. WPF software rendering (the AutoCAD start page and palettes are WPF).
reg 'HKCU\Software\Microsoft\Avalon.Graphics' /v DisableHWAcceleration /t REG_DWORD /d 1

# 4. "Microsoft Sans Serif" (used by the ribbon) built from Liberation Sans.
LIB=$(fc-match -f '%{file}' 'Liberation Sans:style=Regular')
python3 -c 'import fontTools' 2>/dev/null || { echo "python-fonttools is required" >&2; exit 1; }
python3 -I "$REPO/tools/make_micross.py" "$LIB" "$WINEPREFIX/drive_c/windows/Fonts/micross.ttf"
reg 'HKLM\Software\Microsoft\Windows NT\CurrentVersion\Fonts' /v 'Microsoft Sans Serif (TrueType)' /d micross.ttf

"$WINESERVER" -w
echo "Prefix ready: $WINEPREFIX"
