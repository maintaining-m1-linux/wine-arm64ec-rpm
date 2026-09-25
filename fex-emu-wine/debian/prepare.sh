#!/bin/sh
# Prepare the FEX source tree: patches, bundled externals, llvm-mingw.
# Mirrors the %%prep section of the old Fedora fex-emu-wine-git spec.
set -e

SRC="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SRC"

DLCACHE="${DLCACHE:-$SRC/debian/dlcache}"
mkdir -p "$DLCACHE"

fetch() {
    # fetch <url> <dest-dir> [--strip]
    url="$1"
    file="$DLCACHE/$(basename "$url")"
    if [ ! -s "$file" ]; then
        echo "Downloading $url" >&2
        curl -fL --retry 3 -o "$file.tmp" "$url"
        mv "$file.tmp" "$file"
    fi
    echo "$file"
}

# --- our patches (spec Patch100-102) ------------------------------------
# Note: the three upstream commit patches that used to be listed in the
# Fedora spec (a37def2c longjump, 8eaf4541 run_one, c326e2d6 FEXServer
# timeout) are already merged upstream in this snapshot and were never
# applied by the spec's %%prep either; they are kept in this repository
# for reference only.
for p in \
    fex-emu-wine-git-host-page-size \
    fex-emu-wine-git-smc-untrap-host-page \
    fex-emu-wine-git-callback-code-buffer ; do
    echo "Applying $p"
    patch -p1 < "$SRC/../$p.patch"
done

# --- bundled externals (was the spec's lua table) -----------------------
external() {
    # external <owner> <name> <ref> <path-in-tree>
    owner="$1"; name="$2"; ref="$3"; dest="$4"
    url="https://github.com/$owner/$name/archive/$ref/$name-$ref.tar.gz"
    file=$(fetch "$url")
    mkdir -p "$dest"
    tar -xzf "$file" --strip-components=1 -C "$dest"
}

external Sonicadvance1  cpp-optparse    9f94388 Source/Common/cpp-optparse
external catchorg       Catch2          b3fb4b9 External/Catch2
external KhronosGroup   Vulkan-Headers  ee2ec5f External/Vulkan-Headers
external FEX-Emu        drm-headers     3e49836 External/drm-headers
external fmtlib         fmt             c07e2aa External/fmt
external FEX-Emu        jemalloc        8436195 External/jemalloc_glibc
external ericniebler    range-v3        ca1388f External/range-v3
external FEX-Emu        rpmalloc        09142d7 External/rpmalloc
external wolfpld        tracy           650c98e External/tracy
external martinus       unordered_dense 3234af2 External/unordered_dense
external FEX-Emu        vixl            585d860 External/vixl
external Cyan4973       xxhash          e626a72 External/xxhash
external zyantific      zydis           9bfadd6 External/zydis

# --- bylaws llvm-mingw toolchain ----------------------------------------
LLVM_MINGW_DIR="llvm-mingw-20250920-ucrt-ubuntu-22.04-aarch64"
LLVM_MINGW_URL="https://github.com/bylaws/llvm-mingw/releases/download/20250920/$LLVM_MINGW_DIR.tar.xz"
file=$(fetch "$LLVM_MINGW_URL")
tar -xJf "$file" -C "$SRC"
