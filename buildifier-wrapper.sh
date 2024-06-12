#!/usr/bin/env bash

set -euo pipefail

readonly version=v6.4.0
# shellcheck disable=SC2034
readonly darwin_amd64_sha=eeb47b2de27f60efe549348b183fac24eae80f1479e8b06cac0799c486df5bed
# shellcheck disable=SC2034
readonly darwin_arm64_sha=fa07ba0d20165917ca4cc7609f9b19a8a4392898148b7babdf6bb2a7dd963f05
# shellcheck disable=SC2034
readonly linux_amd64_sha=be63db12899f48600bad94051123b1fd7b5251e7661b9168582ce52396132e92
# shellcheck disable=SC2034
readonly linux_arm64_sha=18540fc10f86190f87485eb86963e603e41fa022f88a2d1b0cf52ff252b5e1dd


os=linux
if [[ $OSTYPE == darwin* ]]; then
  os=darwin
fi

arch=amd64
if [[ $(uname -m) == arm64 ]] || [[ $(uname -m) == aarch64 ]]; then
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
