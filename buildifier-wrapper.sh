#!/usr/bin/env bash

set -euo pipefail

readonly version=v8.0.3
# shellcheck disable=SC2034
readonly darwin_amd64_sha=b7a3152cde0b3971b1107f2274afe778c5c154dcdf6c9c669a231e3c004f047e
# shellcheck disable=SC2034
readonly darwin_arm64_sha=674c663f7b5cd03c002f8ca834a8c1c008ccb527a0a2a132d08a7a355883b22d
# shellcheck disable=SC2034
readonly linux_amd64_sha=c969487c1af85e708576c8dfdd0bb4681eae58aad79e68ae48882c70871841b7
# shellcheck disable=SC2034
readonly linux_arm64_sha=bdd9b92e2c65d46affeecaefb54e68d34c272d1f4a8c5b54929a3e92ab78820a
# shellcheck disable=SC2034
readonly windows_amd64_sha=63a242f57e253efe7b9573d739c08a3d0e628efd84015c8dad17d87b6429e443

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
