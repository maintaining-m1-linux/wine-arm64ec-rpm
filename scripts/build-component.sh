#!/bin/bash
# Build one component inside the debian:trixie container.
# Called by wine-docker-deb.sh with the component name as $1.
set -euo pipefail

comp="$1"
HOST=/host
B="/build/$comp"

# skip if a previous run already produced this component's debs
# (FORCE=1 to rebuild)
if [ "${FORCE:-0}" != "1" ] && ls "/out/${comp}_"*.deb >/dev/null 2>&1; then
    echo "=== [$comp] already built, skipping (FORCE=1 to rebuild)"
    exit 0
fi

case "$comp" in
    fex-emu-wine)
        URL="${FEX_URL:-https://github.com/FEX-Emu/FEX/archive/e2f973fe931e6dc2ce523795e51ca1ac3ca85816/FEX-e2f973f.tar.gz}"
        ;;
    wine)
        URL="https://gitlab.winehq.org/wine/wine/-/archive/df15af3652511150490934682202d45af892f887/wine-df15af3652511150490934682202d45af892f887.tar.gz"
        ;;
    wine-dxvk)
        URL="https://github.com/doitsujin/dxvk/archive/25ca63f17f34bdc05a39873ee63907d3cbbfa030/dxvk-25ca63f.tar.gz"
        ;;
    wine-vkd3d-proton)
        URL="https://github.com/HansKristian-Work/vkd3d-proton/archive/v3.0.1/vkd3d-proton-3.0.1.tar.gz"
        ;;
    *)
        echo "unknown component: $comp" >&2
        exit 1
        ;;
esac

echo "=== [$comp] preparing source tree"
rm -rf "$B"
mkdir -p "$B/work"
cd "$B"

TARBALL="/dlcache/$(basename "$URL")"
if [ ! -s "$TARBALL" ]; then
    echo "=== [$comp] downloading $(basename "$URL")"
    curl -fL --retry 3 -o "$TARBALL.tmp" "$URL"
    mv "$TARBALL.tmp" "$TARBALL"
fi
tar -xf "$TARBALL" -C work --strip-components=1

# patches live next to the source tree (spec's ../SOURCES layout);
# the debian packaging goes into the tree
cp "$HOST/$comp"/*.patch "$B/" 2>/dev/null || true
cp -r "$HOST/$comp/debian" work/debian
chmod +x work/debian/rules work/debian/prepare.sh 2>/dev/null || true

# dxvk/vkd3d-proton need winebuild (wine-dev) and its dependencies
if [ "$comp" = "wine-dxvk" ] || [ "$comp" = "wine-vkd3d-proton" ]; then
    echo "=== [$comp] installing wine debs from /out"
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends /out/fex-emu-wine_*.deb /out/wine-dev_*.deb /out/wine-core_*.deb /out/wine-common_*.deb /out/wine-fonts_*.deb
fi

echo "=== [$comp] installing build dependencies"
apt-get update -qq
cd "$B/work"
mk-build-deps --install --remove \
    --tool 'apt-get -o Debug::pkgProblemResolver=yes --no-install-recommends -y' \
    debian/control

echo "=== [$comp] building"
case "$comp" in
    wine) export DEB_BUILD_OPTIONS="parallel=6" ;;
    *)    export DEB_BUILD_OPTIONS="parallel=$(nproc)" ;;
esac
dpkg-buildpackage -b -us -uc

echo "=== [$comp] collecting debs"
cp "$B"/*.deb /out/
ls -la /out/*.deb
