#!/usr/bin/env bash

set -euo pipefail

readonly version=v6.3.3
# shellcheck disable=SC2034
readonly darwin_amd64_sha=3c36a3217bd793815a907a8e5bf81c291e2d35d73c6073914640a5f42e65f73f
# shellcheck disable=SC2034
readonly darwin_arm64_sha=9bb366432d515814766afcf6f9010294c13876686fbbe585d5d6b4ff0ca3e982
# shellcheck disable=SC2034
readonly linux_amd64_sha=42f798ec532c58e34401985043e660cb19d5ae994e108d19298c7d229547ffca
# shellcheck disable=SC2034
readonly linux_arm64_sha=6a03a1cf525045cb686fc67cd5d64cface5092ebefca3c4c93fb6e97c64e07db


os=linux
if [[ $OSTYPE == darwin* ]]; then
  os=darwin
fi

arch=amd64
if [[ $(uname -m) == arm64 ]]; then
  arch=arm64
fi

readonly filename=buildifier-$os-$arch
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
tmp_binary=$(mktemp)

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

  # Protect against races of concurrent hooks downloading the same binary
  if [[ ! -x "$binary" ]]; then
    mv "$tmp_binary" "$binary"
  fi

  exec "$binary" "$@"
else
  echo "error: buildifier sha mismatch" >&2
  rm -f "$binary"
  exit 1
fi
