#!/bin/bash

set -euo pipefail

readonly version=6.1.0
# shellcheck disable=SC2034
readonly darwin_amd64_sha=fc61455f2137c8ea16c299a01cd1d3bfae74edab1da2b97778921691504a2809
# shellcheck disable=SC2034
readonly darwin_arm64_sha=0eef36edd99798fa4ff7099257a847ecaad96a0ef41a5748e9091cd393ee20bc
# shellcheck disable=SC2034
readonly linux_amd64_sha=0b51a6cb81bc3b51466ea2210053992654987a907063d0c2b9c03be29de52eff
# shellcheck disable=SC2034
readonly linux_arm64_sha=5acdd65684105f73d1c65ee4737f6cf388afff8674eb88045aa3c204811b02f3


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
