# wine-aarch64-deb
This is a script for building Wine and FEXEmu Wine DLLs Debian packages with
experimental ARM64EC support. The script also installs these packages
automatically once the build is finished.

This will let you run Windows 32bit and 64bit software on an aarch64 16k Linux
host (e.g. Asahi Linux).

Using Wine in this configuration is very prone to bugs, so you should expect
most software to not run. This is an area of the Wine and FEX projects that is
being actively developed, so support is improving.

This script builds wine by taking mainline wine sources and wine-staging
patches then applies patches from the bylaws
[upstream-arm64ec branch](https://github.com/bylaws/wine/tree/upstream-arm64ec).

For building FEXEmu Wine DLLs, it uses this LLVM-Mingw toolchain provided by
the [bylaws' branch](https://github.com/bylaws/llvm-mingw).

The packages are built inside a debian:trixie docker container using
dpkg-buildpackage; the packaging lives in each component's `debian/`
directory (converted from the old Fedora RPM specs, which were removed).
Binaries produced:

- `wine` (metapackage), `wine-core`, `wine-common`, `wine-desktop`,
  `wine-fonts`, `wine-dev` — wine 11.18 + staging + ARM64EC patches,
  configured `--enable-archs=arm64ec,aarch64,i386 --with-mingw=clang`
- `fex-emu-wine` — the FEX DLLs (libwow64fex/libarm64ecfex)
- `wine-dxvk`, `wine-vkd3d-proton` — Vulkan D3D implementations, selected
  per DLL through update-alternatives

To use this script to generate the packages, you must have a working docker
install on your system. If you haven't set up docker, you can run
```first-time-docker.sh```.

Build everything (artifacts land in ./out):

```
./wine-docker-deb.sh
```

Build and install:

```
./wine-docker-deb.sh install
```
