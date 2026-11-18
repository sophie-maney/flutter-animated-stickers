#!/usr/bin/env bash
# Installs a pinned fvm release for CI and puts it on the job's PATH.
#
#   tool/ci/install_fvm.sh
#
# The archive is checked against the sha256 below before it is unpacked, so
# a changed release asset (or a moved download URL) fails the job instead of
# running unknown code (#52, ADR 0029). To bump fvm, change FVM_VERSION and
# both digests: GitHub lists them on the release page
# (`gh release view <version> -R btwld/fvm --json assets`).
set -euo pipefail

FVM_VERSION=4.3.2

case "$(uname -s)-$(uname -m)" in
  Linux-x86_64)
    platform=linux-x64
    sha256=17dfced05f5b0cb32398dadd0691acc2bc458e8c4b0045a781cd5aa6c85f6ecb
    ;;
  Darwin-arm64)
    platform=macos-arm64
    sha256=c9b1e67e5ff4ddae4710669ff9aa312f750947f68fac5b15fc5d248fb4419342
    ;;
  *)
    echo "no pinned fvm build for $(uname -s)-$(uname -m)" >&2
    exit 1
    ;;
esac

dest="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/fvm-${FVM_VERSION}"
archive="${dest}.tar.gz"
url="https://github.com/btwld/fvm/releases/download/${FVM_VERSION}/fvm-${FVM_VERSION}-${platform}.tar.gz"

curl -fsSL --proto '=https' --tlsv1.2 --retry 3 -o "$archive" "$url"

if command -v sha256sum >/dev/null; then
  actual=$(sha256sum "$archive" | cut -d' ' -f1)
else
  actual=$(shasum -a 256 "$archive" | cut -d' ' -f1)
fi
if [ "$actual" != "$sha256" ]; then
  echo "fvm ${FVM_VERSION} (${platform}): sha256 ${actual}, expected ${sha256}" >&2
  exit 1
fi

rm -rf "$dest"
mkdir -p "$dest"
tar -xzf "$archive" -C "$dest"
rm -f "$archive"
echo "fvm ${FVM_VERSION} (${platform}) installed in ${dest}/fvm"
if [ -n "${GITHUB_PATH:-}" ]; then
  echo "${dest}/fvm" >> "$GITHUB_PATH"
fi
