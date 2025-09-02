#!/usr/bin/env bash

set -euo pipefail

readonly version=v8.2.1
# shellcheck disable=SC2034
readonly darwin_amd64_sha=9f8cffceb82f4e6722a32a021cbc9a5344b386b77b9f79ee095c61d087aaea06
# shellcheck disable=SC2034
readonly darwin_arm64_sha=cfab310ae22379e69a3b1810b433c4cd2fc2c8f4a324586dfe4cc199943b8d5a
# shellcheck disable=SC2034
readonly linux_amd64_sha=6ceb7b0ab7cf66fceccc56a027d21d9cc557a7f34af37d2101edb56b92fcfa1a
# shellcheck disable=SC2034
readonly linux_arm64_sha=3baa1cf7eb41d51f462fdd1fff3a6a4d81d757275d05b2dd5f48671284e9a1a5
# shellcheck disable=SC2034
readonly windows_amd64_sha=802104da0bcda0424a397ac5be0004c372665a70289a6d5146e652ee497c0dc6

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

download() {
  if which wget &> /dev/null; then
    wget --retry-connrefused --quiet --output-document "$2" "$1"
  else
    curl --fail --location --retry 5 --retry-connrefused --silent --output "$2" "$1"
  fi
}

if ! download "$url" "$tmp_binary"; then
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
