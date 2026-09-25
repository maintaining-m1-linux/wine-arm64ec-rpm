#!/bin/bash
# Build the wine ARM64EC stack as Debian packages.
#
#   ./wine-docker-deb.sh            build everything into ./out
#   ./wine-docker-deb.sh install    build, then apt install the result
#                                   (needs sudo) and update the prefix
#
# Replaces the old Fedora/rpmbuild docker flow: the container is now
# debian:trixie and each component is built with dpkg-buildpackage.
set -euo pipefail

cd "$(dirname "$0")"

DEBIAN_VERSION=trixie
COMPONENTS="fex-emu-wine wine wine-dxvk wine-vkd3d-proton"

BUILD_ROOT=build/deb
DLCACHE=build/dl
OUT=out
mkdir -p "$BUILD_ROOT" "$DLCACHE" "$OUT"

#
# builder image: debian + dpkg tooling; build deps come from each
# debian/control via mk-build-deps at build time
#
BUILDER=wine-deb-builder:${DEBIAN_VERSION}
docker build -t "$BUILDER" - <<EOF
FROM debian:${DEBIAN_VERSION}
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential devscripts equivs dpkg-dev debhelper \
      ca-certificates curl wget xz-utils git \
 && rm -rf /var/lib/apt/lists/*
EOF

build_component() {
    local comp="$1"
    echo "=== building $comp ==="
    docker run --rm \
        -v "$PWD:/host:ro" \
        -v "$PWD/$BUILD_ROOT:/build" \
        -v "$PWD/$DLCACHE:/dlcache" \
        -v "$PWD/$OUT:/out" \
        "$BUILDER" bash /host/scripts/build-component.sh "$comp"
}

for comp in $COMPONENTS; do
    build_component "$comp"
done

echo "All components built:"
ls -la "$OUT"

if [ "${1:-}" = "install" ]; then
    echo "Installing built packages..."
    sudo apt-get install -y --allow-downgrades "$OUT"/*.deb
    echo "Updating wine prefix..."
    wineboot -u
    echo "Done."
fi
