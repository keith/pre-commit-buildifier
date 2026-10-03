#!/usr/bin/env bash

set -euo pipefail

readonly version=v10.1.0
# shellcheck disable=SC2034
readonly darwin_amd64_sha=e9e10ff52ec8786fcabccd251c8109ebf31ef7be1f667e27c6e069b96dbdc1f6
# shellcheck disable=SC2034
readonly darwin_arm64_sha=e9804864c407f920f5ecbf03a5e056a8145e11a6ae6b90d2438a3fd106d34473
# shellcheck disable=SC2034
readonly linux_amd64_sha=31b6a8aa1e5c746696788f428729701770ad91925873d8256cb885c60e12c77e
# shellcheck disable=SC2034
readonly linux_arm64_sha=38d2ed845f560b4a16ddee41de906508a95f8dc85b04e0851b0a71e3a70d3890
# shellcheck disable=SC2034
readonly windows_amd64_sha=931a6e9c3844b90ccdb1467ccacd8dd72457e308d2709d624a3c5880d835ac3c
# shellcheck disable=SC2034
readonly windows_arm64_sha=aeffa5a342ce119b52cd7aa17bd9dda22b0406245d90643985749d01f51d2de1

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
