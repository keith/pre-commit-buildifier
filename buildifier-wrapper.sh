#!/bin/bash

set -euo pipefail

readonly version=5.0.1
# shellcheck disable=SC2034
readonly darwin_amd64_sha=2cb0a54683633ef6de4e0491072e22e66ac9c6389051432b76200deeeeaf93fb
# shellcheck disable=SC2034
readonly darwin_arm64_sha=4da23315f0dccabf878c8227fddbccf35545b23b3cb6225bfcf3107689cc4364
# shellcheck disable=SC2034
readonly linux_amd64_sha=3ed7358c7c6a1ca216dc566e9054fd0b97a1482cb0b7e61092be887d42615c5d
# shellcheck disable=SC2034
readonly linux_arm64_sha=c657c628fca72b7e0446f1a542231722a10ba4321597bd6f6249a5da6060b6ff

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
