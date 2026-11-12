#!/usr/bin/env bash
# Fetch the three JieLi AC79 SDK files that tools/build.py needs into $AC79_SDK (see BUILDING.md).
# Only those files are kept. build.py checks them against its reference SHA-256 values.
#
#   AC79_SDK       destination directory (required)
#   AC79_SDK_TAG   default AC79NN_SDK_V1.2.1_2023-12-13, the version the build is tested with
#   AC79_SDK_URL   default https://gitee.com/Jieli-Tech/fw-AC79_AIoT_SDK.git
set -euo pipefail

DEST="${AC79_SDK:?AC79_SDK must be set}"
TAG="${AC79_SDK_TAG:-AC79NN_SDK_V1.2.1_2023-12-13}"
URL="${AC79_SDK_URL:-https://gitee.com/Jieli-Tech/fw-AC79_AIoT_SDK.git}"

# tools/fm1pkg_make.py sdk_file() reads all three from cpu/wl82/tools/
FILES=(
  cpu/wl82/tools/uboot.boot
  cpu/wl82/tools/cfg_tool.bin
  cpu/wl82/tools/cfg/eq_cfg_hw.bin
)

have_all() { # $1 = directory
  local f
  for f in "${FILES[@]}"; do
    [ -s "$1/$f" ] || return 1
  done
}

if have_all "$DEST"; then
  echo "AC79 SDK files already in $DEST"
  exit 0
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

try_clone() { # $1 = filter | plain
  local opts=(--quiet --depth 1 --branch "$TAG" --no-checkout)
  [ "$1" = filter ] && opts+=(--filter=blob:none)
  rm -rf "$work/sdk"
  git clone "${opts[@]}" "$URL" "$work/sdk" || return 1
  # no-cone patterns, anchored at the repository root
  git -C "$work/sdk" sparse-checkout set --no-cone "${FILES[@]/#//}" || return 1
  git -C "$work/sdk" checkout --quiet || return 1
  have_all "$work/sdk"
}

fetched=0
for attempt in 1 2 3; do
  mode=filter
  [ "$attempt" -eq 3 ] && mode=plain   # the last try is for a server that rejects partial clones
  echo "AC79 SDK: attempt $attempt, $mode clone of $TAG"
  if try_clone "$mode"; then
    fetched=1
    break
  fi
  sleep $((attempt * 5))
done

if [ "$fetched" -ne 1 ]; then
  echo "error: could not fetch the AC79 SDK files ($TAG) from $URL" >&2
  exit 1
fi

for f in "${FILES[@]}"; do
  mkdir -p "$DEST/$(dirname "$f")"
  cp "$work/sdk/$f" "$DEST/$f"
done
echo "AC79 SDK files saved in $DEST:"
ls -l "${FILES[@]/#/$DEST/}"
