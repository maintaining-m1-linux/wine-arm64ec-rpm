#!/bin/bash
# Supervise the wine 10.8 downgrade build:
#   watch the docker build; when it fails, auto-fix known
#   "x86 inline asm selected for arm64ec" errors and retry;
#   retries reuse the build tree (make continues from the failure point).
#
# State lives in /tmp/wine108_supervisor so a relaunched supervisor
# continues where a previous one stopped.
set -u

REPO=/home/yjlee/wine-arm64ec-rpm
LOG=/tmp/wine108_build.log
STATE=/tmp/wine108_supervisor
PRISTINE=/tmp/wine108-pristine
MAX_RETRIES=8
WINE_URL=https://gitlab.winehq.org/wine/wine/-/archive/wine-10.8/wine-wine-10.8.tar.gz

mkdir -p "$STATE"
touch "$STATE/touched"
cd "$REPO"

running() { pgrep -f 'build-component.sh wine' >/dev/null 2>&1; }
success() { ls out/wine_10.8*.deb >/dev/null 2>&1; }

build() {
    local extra=""
    if [ -d build/deb/wine/work ]; then
        extra="-e RESUME=1"
        echo "[supervisor] retry with RESUME (incremental from failure point)"
    else
        echo "[supervisor] fresh build"
    fi
    # shellcheck disable=SC2086
    nohup sg docker -c "docker run --rm $extra -e WINE_URL=$WINE_URL \
        -v \"$PWD:/host:ro\" -v \"$PWD/build/deb:/build\" \
        -v \"$PWD/build/dl:/dlcache\" -v \"$PWD/out:/out\" \
        wine-deb-builder:trixie bash /host/scripts/build-component.sh wine" \
        > "$LOG" 2>&1 &
}

ensure_pristine() {
    if [ ! -f "$PRISTINE/configure" ]; then
        echo "[supervisor] extracting pristine reference tree"
        rm -rf "$PRISTINE"; mkdir -p "$PRISTINE"
        tar -xf build/dl/wine-wine-10.8.tar.gz -C "$PRISTINE" --strip-components=1
    fi
}

# --- auto-fixer ---------------------------------------------------------
# Known failure class: 'file.c:LINE:COL: error: invalid input/output
# constraint | unrecognized instruction mnemonic' where an enclosing
# '#if defined(... __i386__/__x86_64__)' guard lacks __arm64ec__.
# Fix: append ' && !defined(__arm64ec__)' to that guard in the build
# tree, remember the file, and regenerate the persistent patch.
auto_fix() {
    local worked=0
    local matches
    matches=$(grep -oE '[A-Za-z0-9_./-]+\.(c|h):[0-9]+:[0-9]+: error: (invalid (input|output) constraint|unrecognized instruction mnemonic)' "$LOG" | sort -u)
    [ -n "$matches" ] || return 1
    while IFS= read -r loc; do
        local file line guardline work
        file=${loc%%:*}
        line=$(echo "$loc" | cut -d: -f2)
        work="build/deb/wine/work/$file"
        [ -f "$work" ] || continue
        # nearest guard above the error that selects x86 and lacks arm64ec
        guardline=$(awk -v L="$line" '
            /^#if.*defined\(__i386__\)/ || /^#if.*defined\(__x86_64__\)/ {
                if ($0 !~ /__arm64ec__/) { g=NR }
            }
            NR==L { print g+0; exit }' "$work")
        [ "$guardline" -ge 1 ] 2>/dev/null || continue
        if sed -n "${guardline}p" "$work" | grep -q '^#if defined('; then
            python3 - "$work" "$guardline" <<'PYEOF'
import sys
path, ln = sys.argv[1], int(sys.argv[2])
lines = open(path).read().split('\n')
i = ln - 1
if '__arm64ec__' in lines[i] or not lines[i].rstrip().endswith(')'):
    sys.exit(1)
lines[i] = lines[i].rstrip() + ' && !defined(__arm64ec__)'
open(path, 'w').write('\n'.join(lines))
PYEOF
            if [ $? -eq 0 ]; then
                echo "$file" >> "$STATE/touched"
                sort -u "$STATE/touched" -o "$STATE/touched"
                worked=1
                echo "[supervisor] auto-fix: $file guard at line $guardline"
            fi
        fi
    done <<< "$matches"
    [ "$worked" = 1 ]
}

regen_patch() {
    ensure_pristine
    local out="wine/generated-arm64ec-fixups.patch"
    : > "$out"
    local f
    while IFS= read -r f; do
        [ -f "$PRISTINE/$f" ] || continue
        if ! cmp -s "$PRISTINE/$f" "build/deb/wine/work/$f"; then
            diff -u --label "a/$f" --label "b/$f" "$PRISTINE/$f" \
                "build/deb/wine/work/$f" >> "$out" || true
        fi
    done < "$STATE/touched"
    [ -s "$out" ] || rm -f "$out"
    [ -f "$out" ] && echo "[supervisor] regenerated $out ($(grep -c '^--- ' "$out") files)"
}

# --- main ---------------------------------------------------------------
# if a build is currently running (e.g. started by the operator), just watch it
while pgrep -f 'supervise-wine108' | grep -v $$ >/dev/null 2>&1; do
    echo "[supervisor] another supervisor is running, waiting for it"
    sleep 120
done

fails=$(cat "$STATE/failures" 2>/dev/null || echo 0)
while [ "$fails" -lt "$MAX_RETRIES" ]; do
    if running; then
        echo "[supervisor] watching running build"
        while running; do sleep 60; done
    fi
    if success; then
        echo "[supervisor] SUCCESS: $(ls out/wine_10.8*.deb | tr '\n' ' ')"
        exit 0
    fi
    fails=$((fails+1)); echo "$fails" > "$STATE/failures"
    echo "[supervisor] build failed (interruption #$fails)"
    if ! auto_fix; then
        echo "[supervisor] ERROR: unfixable failure, last log lines:"
        tail -30 "$LOG"
        exit 1
    fi
    regen_patch
    build
    sleep 10
done
echo "[supervisor] exceeded $MAX_RETRIES retries"
tail -30 "$LOG"
exit 1
