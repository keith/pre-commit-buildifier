#!/usr/bin/env bash

set -euo pipefail

readonly version=v8.0.1
# shellcheck disable=SC2034
readonly darwin_amd64_sha=802b013211dbcf91e3c0658ba33ecb3932ef5a6f6764a0b13efcec4e2df04c83
# shellcheck disable=SC2034
readonly darwin_arm64_sha=833e2afc331b9ad8f6b038ad3d69ceeaf97651900bf2a3a45f54f42cafe0bfd3
# shellcheck disable=SC2034
readonly linux_amd64_sha=1976053ed4decd6dd93170885b4387eddc76ec70dc2697b2e91a9af83269418a
# shellcheck disable=SC2034
readonly linux_arm64_sha=93078c57763493bdc2914ed340544500b8f3497341a62e90f00e9e184c4d9c2c
# shellcheck disable=SC2034
readonly windows_amd64_sha=6edc9247e6d42d27fb67b9509bb795d159a12468faa89e9f290dcadc26571c31

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
