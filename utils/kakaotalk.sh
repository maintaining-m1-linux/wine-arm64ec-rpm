#!/bin/bash
# Launch KakaoTalk PC on the ARM64EC wine build.
#
# KakaoTalk's Themida-style packer (Vox.dll/Vox3.dll) self-modifies code;
# FEX's default SMC tracking (mtrack) misses the modifications and the
# process either dies at startup (stack overflow in the ARM64EC loader
# path on wine 10.8) or crashes in Vox.dll init (wine 11.18).
# FEX_SMCCHECKS=full validates guest code pages before every run, which
# gets the client past the protector and keeps it running.
#
# Usage: kakaotalk.sh [--reinstall]
set -euo pipefail

WINE_BIN="${WINE:-wine}"
# Install layout differs between per-user and system-wide installs.
KAKAO_CANDIDATES=(
    "$HOME/.wine/drive_c/Program Files/Kakao/KakaoTalk/KakaoTalk.exe"
    "$HOME/.wine/drive_c/users/$USER/AppData/Local/Programs/Kakao/KakaoTalk/bin/KakaoTalkUI.exe"
)
KAKAO=""
for c in "${KAKAO_CANDIDATES[@]}"; do
    if [ -f "$c" ]; then KAKAO="$c"; break; fi
done

if [ "${1:-}" = "--reinstall" ] || [ -z "$KAKAO" ]; then
    echo "KakaoTalk not found, running the official installer..."
    SETUP=""
    for s in "$HOME"/다운로드/KakaoTalk_Setup*.exe "$HOME"/Downloads/KakaoTalk_Setup*.exe; do
        [ -f "$s" ] && SETUP="$s" && break
    done
    if [ -z "$SETUP" ]; then
        echo "Downloading KakaoTalk_Setup.exe..."
        curl -fL -o /tmp/KakaoTalk_Setup.exe \
            "https://app-pc.kakaocdn.net/talk/win32/KakaoTalk_Setup.exe"
        SETUP=/tmp/KakaoTalk_Setup.exe
    fi
    "$WINE_BIN" "$SETUP" || true
    for c in "${KAKAO_CANDIDATES[@]}"; do
        if [ -f "$c" ]; then KAKAO="$c"; break; fi
    done
fi

if [ -z "$KAKAO" ]; then
    echo "error: KakaoTalk.exe not found after install" >&2
    exit 1
fi

# FEX full SMC validation is required for the Themida-protected client.
export FEX_SMCCHECKS=full
# Keep the window on the user's desktop session; Wayland preferred.
export WINEDEBUG="${WINEDEBUG:-err+all,err-ntdll}"

echo "Starting KakaoTalk ($KAKAO)..."
cd "$(dirname "$KAKAO")"
exec "$WINE_BIN" "$(basename "$KAKAO")" "$@"
