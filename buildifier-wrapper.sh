#!/bin/bash

set -euo pipefail

readonly version=5.1.0
# shellcheck disable=SC2034
readonly darwin_amd64_sha=c9378d9f4293fc38ec54a08fbc74e7a9d28914dae6891334401e59f38f6e65dc
# shellcheck disable=SC2034
readonly darwin_arm64_sha=745feb5ea96cb6ff39a76b2821c57591fd70b528325562486d47b5d08900e2e4
# shellcheck disable=SC2034
readonly linux_amd64_sha=52bf6b102cb4f88464e197caac06d69793fa2b05f5ad50a7e7bf6fbd656648a3
# shellcheck disable=SC2034
readonly linux_arm64_sha=917d599dbb040e63ae7a7e1adb710d2057811902fdc9e35cce925ebfd966eeb8

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

if echo "$sha  $tmp_binary" | shasum --check --status; then
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
