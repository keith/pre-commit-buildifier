#!/usr/bin/env bash

set -euo pipefail

readonly version=v7.3.1
# shellcheck disable=SC2034
readonly darwin_amd64_sha=375f823103d01620aaec20a0c29c6cbca99f4fd0725ae30b93655c6704f44d71
# shellcheck disable=SC2034
readonly darwin_arm64_sha=5a6afc6ac7a09f5455ba0b89bd99d5ae23b4174dc5dc9d6c0ed5ce8caac3f813
# shellcheck disable=SC2034
readonly linux_amd64_sha=5474cc5128a74e806783d54081f581662c4be8ae65022f557e9281ed5dc88009
# shellcheck disable=SC2034
readonly linux_arm64_sha=0bf86c4bfffaf4f08eed77bde5b2082e4ae5039a11e2e8b03984c173c34a561c
# shellcheck disable=SC2034
readonly windows_amd64_sha=370cd576075ad29930a82f5de132f1a1de4084c784a82514bd4da80c85acf4a8

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
