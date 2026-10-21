#!/bin/sh
# Builds the four patched Wine modules (kernelbase, ole32, urlmon, wineserver)
# and assembles a private Wine in $AUTOCAD_WINE_HOME/wine-custom that reuses
# everything else from the system Wine.
#
# The source version MUST match the installed system Wine (`wine --version`),
# because the unpatched modules are taken from /usr/lib/wine.
set -eu

: "${AUTOCAD_WINE_HOME:=$HOME/.cache/wine-autocad-build}"
REPO=$(cd "$(dirname "$0")/.." && pwd)
VERSION=${1:-$(wine --version | sed 's/^wine-//; s/ .*//')}
MAJOR=$(echo "$VERSION" | cut -d. -f1)
SRC="$AUTOCAD_WINE_HOME/wine-$VERSION"
BUILD="$AUTOCAD_WINE_HOME/build"
W="$AUTOCAD_WINE_HOME/wine-custom"

command -v x86_64-w64-mingw32-gcc >/dev/null || { echo "mingw-w64-gcc is required" >&2; exit 1; }
mkdir -p "$AUTOCAD_WINE_HOME"
cd "$AUTOCAD_WINE_HOME"

if [ ! -d "$SRC" ]; then
    curl -fL -o "wine-$VERSION.tar.xz" "https://dl.winehq.org/wine/source/$MAJOR.x/wine-$VERSION.tar.xz"
    tar -xf "wine-$VERSION.tar.xz"
    patch -d "$SRC" -p1 < "$REPO/wine-autocad.patch"
fi

rm -rf "$BUILD"
mkdir -p "$BUILD"
cd "$BUILD"
# Only PE modules and the server are rebuilt, so every optional library is off.
"$SRC/configure" --enable-archs=x86_64 --without-x --without-wayland --without-freetype \
    --without-gstreamer --without-vulkan --without-opencl --without-cups --without-sane \
    --without-gphoto --without-pcap --without-usb --without-v4l2 --without-pulse \
    --without-alsa --without-oss --without-ffmpeg --without-capi --without-krb5 \
    --without-netapi --without-sdl --without-udev --without-unwind --without-dbus \
    --without-gnutls --without-inotify --without-osmesa --without-opengl \
    --without-fontconfig --without-xinerama > configure.log
make -j"$(nproc)" \
    dlls/kernelbase/x86_64-windows/kernelbase.dll \
    dlls/ole32/x86_64-windows/ole32.dll \
    dlls/urlmon/x86_64-windows/urlmon.dll \
    server/wineserver > make.log

# Private Wine: system binaries and modules, with the patched ones on top.
rm -rf "$W"
mkdir -p "$W/bin" "$W/lib/wine/x86_64-windows" "$W/lib/wine/i386-windows" "$W/share"
cp /usr/bin/wine "$W/bin/"
cp -a /usr/lib/wine/x86_64-unix "$W/lib/wine/"
ln -s /usr/share/wine "$W/share/wine"
for a in x86_64-windows i386-windows; do
    for f in /usr/lib/wine/$a/*; do ln -s "$f" "$W/lib/wine/$a/"; done
done
for m in kernelbase ole32 urlmon; do
    rm "$W/lib/wine/x86_64-windows/$m.dll"
    cp "dlls/$m/x86_64-windows/$m.dll" "$W/lib/wine/x86_64-windows/"
done
cp server/wineserver "$W/bin/wineserver"

echo "Patched Wine $VERSION ready in $W"
