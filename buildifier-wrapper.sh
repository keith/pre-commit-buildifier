#!/bin/bash

set -euo pipefail

readonly version=4.0.1
# shellcheck disable=SC2034
readonly darwin_amd64_sha=f4d0ede5af04b32671b9a086ae061df8f621f48ea139b01b3715bfa068219e4a
# TODO: Separate once it's vendored
# shellcheck disable=SC2034
readonly darwin_arm64_sha=$darwin_amd64_sha
# shellcheck disable=SC2034
readonly linux_amd64_sha=069a03fc1fa46135e3f71e075696e09389344710ccee798b2722c50a2d92d55a
# shellcheck disable=SC2034
readonly linux_arm64_sha=bfcad27eb6ec288ca200f9875ca16a2eec5958c8224ddd16cf9916193af46e61

os=linux
if [[ $OSTYPE == darwin* ]]; then
  os=darwin
fi

arch=amd64
if [[ $(uname -m) == arm64 ]]; then
  arch=arm64

  # TODO: Remove once it's vendored
  if [[ $OSTYPE == darwin* ]]; then
    arch=amd64
  fi
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

if ! curl --fail --location --retry 5 --retry-connrefused --silent --output "$binary" "$url"; then
  echo "error: failed to download buildifier" >&2
  exit 1
fi

if echo "$sha  $binary" | shasum --check --status; then
  chmod +x "$binary"
  exec "$binary" "$@"
else
  echo "error: buildifier sha mismatch" >&2
  rm -f "$binary"
  exit 1
fi
