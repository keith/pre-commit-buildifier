#!/bin/bash

set -euo pipefail

readonly version=4.2.0
# shellcheck disable=SC2034
readonly darwin_amd64_sha=c46ce67b2d98837ec0bdc38cc1032709499c2907fbae874c0bcdda5f1dd1450b
# shellcheck disable=SC2034
readonly darwin_arm64_sha=a1700e9453fce304bf68aba02de75f5f291720ea1ad2eaf8147e4940c0058e09
# shellcheck disable=SC2034
readonly linux_amd64_sha=3426f28d817ee5f4c5eba88bfa7c93b0cb9ab7784dd0d065d1e8e64a3fe9f680
# shellcheck disable=SC2034
readonly linux_arm64_sha=95cbf539dae9250c5e5578f40b1895495d4e4befb86c51be1754f02864be8551

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
readonly binary=$binary_dir/buildifier

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
  # Protect against races of concurrent hooks downloading the same binary
  if [[ ! -x "$binary" ]]; then
    mv "$tmp_binary" "$binary"
    chmod +x "$binary"
  fi

  exec "$binary" "$@"
else
  echo "error: buildifier sha mismatch" >&2
  rm -f "$binary"
  exit 1
fi
