#!/bin/sh
# Prepare the vkd3d-proton source tree: bundled externals + llvm-mingw.
# Mirrors the %%prep section of the old Fedora spec.
set -e

SRC="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SRC"

DLCACHE="${DLCACHE:-$SRC/debian/dlcache}"
mkdir -p "$DLCACHE"

fetch() {
    url="$1"
    file="$DLCACHE/$(basename "$url")"
    if [ ! -s "$file" ]; then
        echo "Downloading $url" >&2
        curl -fL --retry 3 -o "$file.tmp" "$url"
        mv "$file.tmp" "$file"
    fi
    echo "$file"
}

external() {
    owner="$1"; name="$2"; ref="$3"; shift 3
    url="https://github.com/$owner/$name/archive/$ref/$name-$ref.tar.gz"
    file=$(fetch "$url")
    for dest in "$@"; do
        mkdir -p "$dest"
        tar -xzf "$file" --strip-components=1 -C "$dest"
    done
}

external KhronosGroup        SPIRV-Headers f88a2d7 khronos/SPIRV-Headers subprojects/dxil-spirv/third_party/spirv-headers
external KhronosGroup        Vulkan-Headers ad9ce12 khronos/Vulkan-Headers
external HansKristian-Work   dxil-spirv     62dbb07 subprojects/dxil-spirv
external doitsujin           dxbc-spirv     29c93ae subprojects/dxil-spirv/subprojects/dxbc-spirv
external KhronosGroup        SPIRV-Headers c8ad050 subprojects/dxil-spirv/subprojects/dxbc-spirv/submodules/spirv_headers

file=$(fetch "https://github.com/bylaws/llvm-mingw/releases/download/20250920/llvm-mingw-20250920-ucrt-ubuntu-22.04-aarch64.tar.xz")
tar -xJf "$file" -C "$SRC"
