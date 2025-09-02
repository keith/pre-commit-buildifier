#!/usr/bin/env bash

set -euo pipefail

readonly version=v8.2.0
# shellcheck disable=SC2034
readonly darwin_amd64_sha=309b3c3bfcc4b1533d5f7f796adbd266235cfb6f01450f3e37423527d209a309
# shellcheck disable=SC2034
readonly darwin_arm64_sha=e08381a3ed1d59c0a17d1cee1d4e7684c6ce1fc3b5cfa1bd92a5fe978b38b47d
# shellcheck disable=SC2034
readonly linux_amd64_sha=3e79e6c0401b5f36f8df4dfc686127255d25c7eddc9599b8779b97b7ef4cdda7
# shellcheck disable=SC2034
readonly linux_arm64_sha=c624a833bfa64d3a457ef0235eef0dbda03694768aab33f717a7ffd3f803d272
# shellcheck disable=SC2034
readonly windows_amd64_sha=a27fcf7521414f8214787989dcfb2ac7d3f7c28b56e44384e5fa06109953c2f1

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
