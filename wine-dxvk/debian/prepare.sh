#!/bin/sh
# Prepare the dxvk source tree: bundled externals + llvm-mingw.
# Mirrors the %%prep section of the old Fedora wine-dxvk-git spec.
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
    owner="$1"; name="$2"; ref="$3"; dest="$4"
    url="https://github.com/$owner/$name/archive/$ref/$name-$ref.tar.gz"
    file=$(fetch "$url")
    mkdir -p "$dest"
    tar -xzf "$file" --strip-components=1 -C "$dest"
}

external doitsujin     dxbc-spirv            37a9774 subprojects/dxbc-spirv
external KhronosGroup  SPIRV-Headers         c8ad050 subprojects/dxbc-spirv/submodules/spirv_headers
external doitsujin     libdisplay-info       275e645 subprojects/libdisplay-info
external KhronosGroup  SPIRV-Headers         04f10f6 include/spirv
external KhronosGroup  Vulkan-Headers        8864cdc include/vulkan
external misyltoad     mingw-directx-headers 9df86f2 include/native/directx

file=$(fetch "https://github.com/bylaws/llvm-mingw/releases/download/20250920/llvm-mingw-20250920-ucrt-ubuntu-22.04-aarch64.tar.xz")
tar -xJf "$file" -C "$SRC"
