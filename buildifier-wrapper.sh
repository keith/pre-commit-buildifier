#!/bin/bash

set -euo pipefail

readonly version=4.2.3
# shellcheck disable=SC2034
readonly darwin_amd64_sha=954ec397089344b1564e45dc095e9331e121eb0f20e72032fcc8e94de78e5663
# shellcheck disable=SC2034
readonly darwin_arm64_sha=9434043897a3c3821fda87046918e5a6c4320d8352df700f62046744c4d168a3
# shellcheck disable=SC2034
readonly linux_amd64_sha=a19126536bae9a3917a7fc4bdbbf0378371a1d1683ab2415857cf53bce9dee49
# shellcheck disable=SC2034
readonly linux_arm64_sha=39bd9d01d3638902a1e4cef353048ed160f0575f5df1bef175bd7637386d183c

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
