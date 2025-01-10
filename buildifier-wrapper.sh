#!/usr/bin/env bash

set -euo pipefail

readonly version=v8.0.0
# shellcheck disable=SC2034
readonly darwin_amd64_sha=00c54f5363899653b6d5c86808d65447e10ab658a1b242707449c169c8f879d0
# shellcheck disable=SC2034
readonly darwin_arm64_sha=cb2135ff8489bf3e1a1ba60be7d2cdab904dde7812426d4c72c021024c617fcb
# shellcheck disable=SC2034
readonly linux_amd64_sha=3482807cafadb64912ad912bdc752a8d4118d12b2f493f66f961f94d60f76d6a
# shellcheck disable=SC2034
readonly linux_arm64_sha=4f3a47fcb0d49388cc0c703ba43d83e10c51c35806640d5cab820720ee0540d7
# shellcheck disable=SC2034
readonly windows_amd64_sha=bbd11c7e68a985bcb14d1852f6855748dc1c6d98f9ad904d9d52381aee983a63

os=linux
extension=""
if [[ $OSTYPE == darwin* ]]; then
  os=darwin
elif [[ $OSTYPE == msys* || $OSTYPE == cygwin* || $OSTYPE == win32 ]]; then
  os=windows
  extension=".exe"
fi

arch=amd64
if [[ $(uname -m) == arm64 ]] || [[ $(uname -m) == aarch64 ]]; then
  arch=arm64
fi

readonly filename=buildifier-$os-${arch}${extension}
readonly url=https://github.com/bazelbuild/buildtools/releases/download/$version/$filename
readonly binary_dir=~/.cache/pre-commit/buildifier/$os-$arch-$version/buildifier
readonly binary=$binary_dir/buildifier-$1
shift

if [[ -x "$binary" ]]; then
  exec "$binary" "$@"
fi

readonly sha_accessor=${os}_${arch}_sha
readonly sha="${!sha_accessor}"

mkdir -p "$binary_dir"
# Create tmp_binary in the same directory as binary to make mv atomic.
tmp_binary="$(mktemp --tmpdir="$binary_dir")"
trap 'rm -f "$tmp_binary"' EXIT

if ! curl --fail --location --retry 5 --retry-connrefused --silent --output "$tmp_binary" "$url"; then
  echo "error: failed to download buildifier" >&2
  exit 1
fi

shabin=shasum
if ! command -v "$shabin" >/dev/null; then
  shabin=sha256sum
fi

if echo "$sha  $tmp_binary" | $shabin --check --status; then
  chmod +x "$tmp_binary"
  mv "$tmp_binary" "$binary"
  exec "$binary" "$@"
else
  echo "error: buildifier sha mismatch" >&2
  rm -f "$binary"
  exit 1
fi
