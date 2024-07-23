#!/usr/bin/env bash

set -euo pipefail

readonly version=v7.1.2
# shellcheck disable=SC2034
readonly darwin_amd64_sha=687c49c318fb655970cf716eed3c7bfc9caeea4f2931a2fd36593c458de0c537
# shellcheck disable=SC2034
readonly darwin_arm64_sha=d0909b645496608fd6dfc67f95d9d3b01d90736d7b8c8ec41e802cb0b7ceae7c
# shellcheck disable=SC2034
readonly linux_amd64_sha=28285fe7e39ed23dc1a3a525dfcdccbc96c0034ff1d4277905d2672a71b38f13
# shellcheck disable=SC2034
readonly linux_arm64_sha=c22a44eee37b8927167ee6ee67573303f4e31171e7ec3a8ea021a6a660040437
# shellcheck disable=SC2034
readonly windows_amd64_sha=a8331515019d8d3e01baa1c76fda19e8e6e3e05532d4b0bce759bd759d0cafb7

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
