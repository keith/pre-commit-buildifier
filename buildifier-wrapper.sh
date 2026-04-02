#!/usr/bin/env bash

set -euo pipefail

readonly version=v8.5.1
# shellcheck disable=SC2034
readonly darwin_amd64_sha=31de189e1a3fe53aa9e8c8f74a0309c325274ad19793393919e1ca65163ca1a4
# shellcheck disable=SC2034
readonly darwin_arm64_sha=62836a9667fa0db309b0d91e840f0a3f2813a9c8ea3e44b9cd58187c90bc88ba
# shellcheck disable=SC2034
readonly linux_amd64_sha=887377fc64d23a850f4d18a077b5db05b19913f4b99b270d193f3c7334b5a9a7
# shellcheck disable=SC2034
readonly linux_arm64_sha=947bf6700d708026b2057b09bea09abbc3cafc15d9ecea35bb3885c4b09ccd04
# shellcheck disable=SC2034
readonly windows_amd64_sha=f4ecb9c73de2bc38b845d4ee27668f6248c4813a6647db4b4931a7556052e4e1
# shellcheck disable=SC2034
readonly windows_arm64_sha=55a276ad8b1ff46be48bf64e432264034ea69a45aa3914e89c1d1936f5c2d85c

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
readonly default_base_url=https://github.com/bazelbuild/buildtools/releases/download/$version
readonly binary_dir=~/.cache/pre-commit/buildifier/$os-$arch-$version/buildifier
readonly binary=$binary_dir/buildifier-$1
shift

# Parse --buildifier-base-url argument if present.
base_url_arg=""
buildifier_args=()
for arg in "$@"; do
  if [[ $arg == --buildifier-base-url=* ]]; then
    base_url_arg="${arg#--buildifier-base-url=}"
  else
    buildifier_args+=("$arg")
  fi
done
# Replace positional args with filtered args (handles empty array safely with set -u).
set -- ${buildifier_args[@]+"${buildifier_args[@]}"}

readonly base_url=${base_url_arg:-${BUILDIFIER_BASE_URL:-$default_base_url}}
readonly url=$base_url/$filename

# Unset DISPLAY to prevent deprecation warning about selecting
# diff program via environment variables. WSL always sets DISPLAY.
unset DISPLAY

if [[ -x "$binary" ]]; then
  exec "$binary" "$@"
fi

readonly sha_accessor=${os}_${arch}_sha
readonly sha="${!sha_accessor}"

mkdir -p "$binary_dir"
# Create tmp_binary in the same directory as binary to make mv atomic.
tmp_binary="$(mktemp --tmpdir="$binary_dir")"
trap 'rm -f "$tmp_binary"' EXIT

download() {
  if which wget &> /dev/null; then
    wget --retry-connrefused --quiet --output-document "$2" "$1"
  else
    curl --fail --location --retry 5 --retry-connrefused --silent --output "$2" "$1"
  fi
}

if ! download "$url" "$tmp_binary"; then
  echo "error: failed to download buildifier" >&2
  exit 1
fi

shabin=shasum
if ! command -v "$shabin" >/dev/null; then
  shabin=sha256sum
fi

if echo "$sha  $tmp_binary" | $shabin --check --status; then
  chmod +x "$tmp_binary"
  mv "$tmp_binary" "$binary"
  exec "$binary" "$@"
else
  echo "error: buildifier sha mismatch" >&2
  rm -f "$binary"
  exit 1
fi
