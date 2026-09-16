#!/usr/bin/env bash

set -euo pipefail

readonly version=v10.0.1
# shellcheck disable=SC2034
readonly darwin_amd64_sha=1d02bb9148cadf2cbee330f9bd657352c765b52b68a03d970e10e47706bdc436
# shellcheck disable=SC2034
readonly darwin_arm64_sha=afb78f350319b59cc51d6add3a5f3ba68e63e5d88f68c5a9ea6328a07084d319
# shellcheck disable=SC2034
readonly linux_amd64_sha=e0ea28e2d639347724435ebafe0531fd764fbf20eec6a23000c81edd0d58e51d
# shellcheck disable=SC2034
readonly linux_arm64_sha=6d7aebd23aa85847a66d517bb6220d95f24a2752e62cce0f089145b680b539c7
# shellcheck disable=SC2034
readonly windows_amd64_sha=ac33edf5da6137ec816f14d7a07889c96c45d669a8d58c864e9c3d0a62063fcd
# shellcheck disable=SC2034
readonly windows_arm64_sha=cb02bf1d65ddb624dd2c20b7a7ae88bfc5d9bc3e39112888a8bc6b2f6f5faa20

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
readonly binary_dir="${XDG_CACHE_HOME:-$HOME/.cache}"/pre-commit/buildifier/$os-$arch-$version/buildifier
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
